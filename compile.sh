#!/bin/bash

# Enable strict mode: exit on error, treat unset variables as errors, fail on pipeline errors
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/.bin"

# Mapping control file versions (from main.bcf) to Biber versions
get_biber_version() {
    local bcf_ver="$1"
    case "$bcf_ver" in
        "3.8") echo "2.17" ;;
        "3.9") echo "2.18" ;;
        "3.10") echo "2.19" ;;
        "3.11") echo "2.21" ;;
        *) echo "2.17" ;; # Default fallback for future versions
    esac
}

# Clear Biber PAR cache and temporary files
clean_cache() {
    echo "Cleaning Biber and LaTeX build artifacts..."
    
    # Try to find and remove Biber PAR cache
    # Check global biber first, then local biber
    local biber_cmd=""
    if command -v biber &> /dev/null; then
        biber_cmd="biber"
    elif [ -f "$BIN_DIR/biber" ]; then
        biber_cmd="$BIN_DIR/biber"
    fi

    if [ -n "$biber_cmd" ]; then
        # Run biber --cache to locate PAR directory. It might fail if cache is corrupted, so || true
        local par_cache
        par_cache=$("$biber_cmd" --cache 2>/dev/null || true)
        if [ -n "$par_cache" ] && [ -d "$par_cache" ]; then
            echo "Removing Biber PAR cache directory: $par_cache"
            rm -rf "$par_cache"
        fi
    fi

    # Clean local .bin cache
    if [ -d "$BIN_DIR" ]; then
        echo "Removing local binary cache directory: $BIN_DIR"
        rm -rf "$BIN_DIR"
    fi

    # Clean LaTeX intermediate files
    echo "Removing LaTeX intermediate files..."
    rm -f "$SCRIPT_DIR"/*.aux "$SCRIPT_DIR"/*.bbl "$SCRIPT_DIR"/*.bcf "$SCRIPT_DIR"/*.blg \
          "$SCRIPT_DIR"/*.fdb_latexmk "$SCRIPT_DIR"/*.fls "$SCRIPT_DIR"/*.log \
          "$SCRIPT_DIR"/*.run.xml "$SCRIPT_DIR"/*.synctex.gz "$SCRIPT_DIR"/*.out
    
    echo "Clean completed."
}

# Print help documentation
print_help() {
    echo "APA 7th Edition LaTeX Template Compilation Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -c, --clean-cache   Clear Biber PAR cache, local .bin, and LaTeX intermediate files"
    echo "  -h, --help          Show this help message"
}

# Download and cache Biber locally
download_biber() {
    local version="$1"
    echo "Downloading and caching Biber $version locally in .bin/..."
    
    # Ensure binary directory exists
    mkdir -p "$BIN_DIR"

    # Pre-flight check for download tools
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required to download Biber but was not found." >&2
        exit 1
    fi
    if ! command -v tar &> /dev/null; then
        echo "Error: tar is required to extract Biber but was not found." >&2
        exit 1
    fi

    OS="$(uname -s)"
    local URL=""
    local FILE=""
    
    if [ "$OS" = "Darwin" ]; then
        # macOS
        URL="https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$version/binaries/MacOS/biber-darwin_universal.tar.gz/download"
        FILE="$BIN_DIR/biber-darwin_universal.tar.gz"
    elif [ "$OS" = "Linux" ]; then
        # Linux (checks architecture)
        local ARCH
        ARCH="$(uname -m)"
        if [ "$ARCH" != "x86_64" ]; then
            echo "Warning: Detected CPU architecture is $ARCH. The precompiled Linux binary is built for x86_64 and may not run on your platform."
        fi
        URL="https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$version/binaries/Linux/biber-linux_x86_64.tar.gz/download"
        FILE="$BIN_DIR/biber-linux_x86_64.tar.gz"
    else
        echo "Error: Unsupported OS: $OS. Please install Biber ($version) manually." >&2
        exit 1
    fi

    # Download with curl: follow redirects (-L), fail on server errors (-f), show error messages (-S),
    # suppress progress bar (-s), timeout after 30s, and retry up to 3 times with exponential backoff.
    if ! curl -fsSL --connect-timeout 15 --retry 3 --retry-delay 2 "$URL" -o "$FILE"; then
        echo "Error: Failed to download Biber from SourceForge. Please check your network connection." >&2
        rm -f "$FILE"
        exit 1
    fi

    # Unpack to BIN_DIR
    if ! tar -xzf "$FILE" -C "$BIN_DIR" biber; then
        echo "Error: Failed to extract Biber archive." >&2
        rm -f "$FILE"
        exit 1
    fi
    rm -f "$FILE"
    
    # Make executable
    chmod +x "$BIN_DIR/biber"
    
    # Remove macOS quarantine flag if on macOS
    if [ "$OS" = "Darwin" ]; then
        xattr -d com.apple.quarantine "$BIN_DIR/biber" 2>/dev/null || true
    fi

    # Validate that the downloaded binary is functional
    if ! "$BIN_DIR/biber" --version &>/dev/null; then
        echo "Error: Downloaded Biber binary is not functional or cache initialization failed." >&2
        # Try clearing PAR cache in case it failed during initialization
        local par_cache
        par_cache=$("$BIN_DIR/biber" --cache 2>/dev/null || true)
        if [ -n "$par_cache" ] && [ -d "$par_cache" ]; then
            rm -rf "$par_cache"
        fi
        exit 1
    fi
}

run_main() {
    # Check if Tectonic is installed
    if ! command -v tectonic &> /dev/null; then
        echo "Error: Tectonic is not installed. Please install Tectonic before compiling." >&2
        echo "  macOS:   brew install tectonic" >&2
        echo "  Windows: winget install Tectonic.Tectonic" >&2
        echo "  Linux:   Please use your package manager or visit https://tectonic-typesetting.github.io/" >&2
        exit 1
    fi

    # Parse command line options
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--clean-cache)
                clean_cache
                exit 0
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                print_help
                exit 1
                ;;
        esac
    done

    # Default Biber version selection (default to 2.17 for current Tectonic packages)
    local biber_ver="2.17"

    # Self-healing check: If main.bcf exists from a previous run, read the expected version immediately
    if [ -f "$SCRIPT_DIR/main.bcf" ]; then
        local bcf_ver
        bcf_ver=$(grep -Eo 'controlfile version="[0-9]+\.[0-9]+"' "$SCRIPT_DIR/main.bcf" | grep -Eo '[0-9]+\.[0-9]+' | head -n 1 || true)
        if [ -n "$bcf_ver" ]; then
            biber_ver=$(get_biber_version "$bcf_ver")
        fi
    fi

    # Check if a compatible global biber is already available and functional
    local global_biber_ver=""
    if command -v biber &> /dev/null; then
        # Ensure it works and doesn't crash on PAR cache corruption
        global_biber_ver=$(biber --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+' | head -n 1 || true)
    fi

    if [ "$global_biber_ver" = "$biber_ver" ]; then
        echo "Compatible global Biber version $global_biber_ver detected. Skipping local download."
    else
        # Ensure local Biber exists, is the correct version, and is functional
        local local_biber_ok=false
        if [ -x "$BIN_DIR/biber" ]; then
            local local_ver
            local_ver=$("$BIN_DIR/biber" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+' | head -n 1 || true)
            if [ "$local_ver" = "$biber_ver" ]; then
                local_biber_ok=true
            fi
        fi

        if [ "$local_biber_ok" = "false" ]; then
            download_biber "$biber_ver"
        fi
        export PATH="$BIN_DIR:$PATH"
    fi

    echo "Compiling document with Tectonic..."
    # Run tectonic
    local exit_code=0
    tectonic --keep-intermediates "$SCRIPT_DIR/main.tex" || exit_code=$?

    # If compilation fails, check if the .bcf version requires a different Biber version
    if [ $exit_code -ne 0 ] && [ -f "$SCRIPT_DIR/main.bcf" ]; then
        local bcf_ver
        bcf_ver=$(grep -Eo 'controlfile version="[0-9]+\.[0-9]+"' "$SCRIPT_DIR/main.bcf" | grep -Eo '[0-9]+\.[0-9]+' | head -n 1 || true)
        if [ -n "$bcf_ver" ]; then
            local required_ver
            required_ver=$(get_biber_version "$bcf_ver")
            
            if [ "$required_ver" != "$biber_ver" ]; then
                echo "Version mismatch detected. BibLaTeX control file requires Biber $required_ver (used $biber_ver)."
                download_biber "$required_ver"
                echo "Retrying compilation with Biber $required_ver..."
                exit_code=0
                tectonic --keep-intermediates "$SCRIPT_DIR/main.tex" || exit_code=$?
            else
                # If versions match but compile still failed, check if biber is broken/corrupted
                echo "Compilation failed. Checking if Biber PAR cache corruption is the cause..."
                local biber_cmd="biber"
                if [ -x "$BIN_DIR/biber" ]; then
                    biber_cmd="$BIN_DIR/biber"
                fi
                
                if ! "$biber_cmd" --version &>/dev/null; then
                    echo "Biber execution error detected. Attempting self-healing of Biber PAR cache..."
                    local par_cache
                    par_cache=$("$biber_cmd" --cache 2>/dev/null || true)
                    if [ -n "$par_cache" ] && [ -d "$par_cache" ]; then
                        echo "Clearing Biber PAR cache: $par_cache"
                        rm -rf "$par_cache"
                    fi
                    echo "Retrying compilation after cache clearance..."
                    exit_code=0
                    tectonic --keep-intermediates "$SCRIPT_DIR/main.tex" || exit_code=$?
                fi
            fi
        fi
    fi

    if [ $exit_code -eq 0 ]; then
        echo "Success! main.pdf has been generated."
        return 0
    else
        echo "Error: Compilation failed. If the error persists, try running with: $0 --clean-cache" >&2
        return 1
    fi
}

# Only run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_main "$@"
fi
