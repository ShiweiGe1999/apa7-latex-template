# APA 7th Edition LaTeX Template (Cross-Platform)

A professional, out-of-the-box LaTeX template for typesetting academic essays, student papers, and journal manuscripts in strict compliance with the **APA 7th Edition** guidelines. 

This template leverages the official `apa7` document class and is designed to build seamlessly on **macOS, Windows, and Linux** using **Tectonic** (a modern, self-contained TeX engine) and **BibLaTeX** (using a dynamically downloaded, compatible Biber backend).

---

## Key Features

- **APA 7 Compliance:** Native support for both student paper formats (`[stu]`) and professional manuscript formats (`[man]`).
- **Zero-Configuration Build:** Compiles in a single command using Tectonic, automatically downloading required packages on the fly.
- **Self-Healing Versioning:** The build scripts automatically parse Tectonic's output to find the exact required Biber version and download/cache it locally, preventing version mismatch issues.
- **Lightweight Repository:** No bulky Biber binaries are committed to Git. The `.bin/` cache folder is excluded via `.gitignore`.
- **References Page Formatting:** Automatic page breaks and hanging indents formatted to APA standards.

---

## File Structure

```text
apa7-latex-template/
├── .gitignore          # Excludes compiled PDFs, cached binaries, and editor artifacts
├── README.md           # Documentation and usage guide
├── compile.sh          # One-click compilation shell script (macOS/Linux)
├── compile.bat         # One-click compilation Batch script (Windows CMD)
├── compile.ps1         # One-click compilation PowerShell script (Windows PowerShell)
├── main.tex            # Main LaTeX document with metadata & placeholders
└── references.bib      # BibLaTeX database containing sample entry citations
```
*(On first execution, the scripts will create a `.bin/` folder to cache the downloaded Biber binary. This folder is ignored by Git.)*

---

## Getting Started

First, install **Tectonic**. It handles packages automatically and compiles documents cleanly without requiring a full TeX Live installation (which is several gigabytes in size).

### macOS
1. Install Tectonic via [Homebrew](https://brew.sh):
   ```bash
   brew install tectonic
   ```
2. Compile the document:
   ```bash
   ./compile.sh
   ```

### Windows
1. Install Tectonic using `winget` (built into Windows 10/11):
   ```powershell
   winget install Tectonic.Tectonic
   ```
   *(Alternatively, you can install via Scoop: `scoop install tectonic` or Chocolatey: `choco install tectonic`)*
2. Compile the document:
   - Using **CMD**: Double-click `compile.bat` or run:
     ```cmd
     compile.bat
     ```
   - Using **PowerShell**: Run:
     ```powershell
     .\compile.ps1
     ```

Upon successful compilation, your formatted paper will be generated as `main.pdf`.

---

## Solving the Biber Compatibility Issue

### The Problem
`biblatex` and its bibliography processing backend, `biber`, are strictly version-locked. Tectonic utilizes a reproducible online TeX Live snapshot containing `biblatex 3.17` (which expects control file version `3.8`). However, system package managers (like Homebrew on macOS or Scoop/Choco on Windows) often install much newer versions of Biber (e.g., `2.21`, which expects control file version `3.11`). Attempting to compile with mismatched versions yields:
```text
Found biblatex control file version 3.8, expected version 3.11.
This means that your biber (2.21) and biblatex (3.17) versions are incompatible.
```

### The Solution (Automated Self-Healing Pipeline)
To ensure the repository is maintainable long-term, Biber binaries are not committed to Git. Instead, the provided compilation scripts (`compile.sh` and `compile.ps1`) handle this dynamically:
1. They search for a globally installed version of Biber and check if its version matches what the paper requires.
2. If there is a version mismatch (or no global Biber is present), they parse the compiled `.bcf` (BibLaTeX Control File) to extract the required control file version.
3. They map this control file version to the exact required Biber version, download it from SourceForge, extract it to a local `.bin/` directory, and prepend it to the compilation environment `$PATH`.
4. If a Tectonic update changes the underlying package versions in the future, the compilation scripts automatically detect this on the next build, download the updated Biber version, and heal the build environment without requiring any user configuration.

---

## Document Settings & Customization

### Switching Document Modes
The `apa7` document class supports multiple layouts. Change the options in `main.tex`:

```latex
\documentclass[stu, 12pt, american]{apa7}
```

- **`[stu]` (Student Paper):** Formats the document according to APA guidelines for student assignments. Suppresses the running head and abstract page, and adds fields for course title, instructor, and due date.
- **`[man]` (Manuscript):** Formats the document as a submission-ready manuscript for journal publication. Includes running heads, page headers, and an abstract page.
- **`[jou]` (Journal):** Formats the paper in a compact, two-column layout mimicking a published journal article.

### Citations Usage
Citations should be managed dynamically using standard `biblatex` macros:
- **Parenthetical Citation:** `\parencite{citation_key}` renders as `(Doe & Smith, 2026)`.
- **Narrative Citation:** `\textcite{citation_key}` renders as `Doe and Smith (2026)`.
- **Year-Only Citation:** `\parencite*{citation_key}` renders as `(2026)`.

Add or modify references inside `references.bib`.

---

## Running Unit Tests

To verify version mapping, regex parsing, and script directory behaviors:
- **macOS/Linux:** Run the test script in your terminal:
  ```bash
  ./tests/test_compile.sh
  ```
- **Windows (PowerShell):** Run:
  ```powershell
  .\tests\test_compile.ps1
  ```

---

## License

This project is open-source and free to use. Modify and distribute it to suit your needs.
