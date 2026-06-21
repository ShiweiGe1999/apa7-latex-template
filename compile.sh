#!/bin/bash
# Compilation script for the APA 7th edition paper
# Uses the locally downloaded biber 2.17 to avoid compatibility issues.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"

echo "Compiling document with Tectonic..."
tectonic main.tex

if [ $? -eq 0 ]; then
  echo "Success! main.pdf has been generated."
else
  echo "Error during compilation."
  exit 1
fi
