# APA 7th Edition LaTeX Template (Cross-Platform)

A professional, out-of-the-box LaTeX template for typesetting academic essays, student papers, and journal manuscripts in strict compliance with the **APA 7th Edition** guidelines. 

This template leverages the official `apa7` document class and is designed to build seamlessly on **macOS, Windows, and Linux** using **Tectonic** (a modern, self-contained TeX engine) and **BibLaTeX** (using a bundled, compatible Biber backend).

---

## Key Features

- **APA 7 Compliance:** Native support for both student paper formats (`[stu]`) and professional manuscript formats (`[man]`).
- **Zero-Configuration Build:** Compiles in a single command using Tectonic, automatically downloading required packages on the fly.
- **Self-Contained Bibliography:** Resolves the notorious `biblatex`/`biber` version mismatch issue by bundling compatible local Biber binaries for both Windows and macOS.
- **References Page Formatting:** Automatic page breaks and hanging indents formatted to APA standards.

---

## File Structure

```text
apa7-latex-template/
├── .gitignore          # Excludes compiled PDFs, system logs, and editor artifacts
├── README.md           # Documentation and usage guide
├── biber               # Precompiled Biber 2.17 binary (Universal macOS binary)
├── biber.exe           # Precompiled Biber 2.17 binary (Windows 64-bit binary)
├── compile.sh          # One-click compilation shell script (macOS/Linux)
├── compile.bat         # One-click compilation Batch script (Windows CMD)
├── compile.ps1         # One-click compilation PowerShell script (Windows PowerShell)
├── main.tex            # Main LaTeX document with metadata & placeholders
└── references.bib      # BibLaTeX database containing sample entry citations
```

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

### The Solution
This repository bundles the **Biber 2.17** binaries for both macOS (`biber`) and Windows (`biber.exe`). The provided compilation scripts automatically configure the command environment path to prioritize the local binary over the system-installed Biber, ensuring a successful build out-of-the-box.

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

## License

This project is open-source and free to use. Modify and distribute it to suit your needs.
