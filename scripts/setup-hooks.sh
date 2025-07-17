#!/bin/bash

# Setup script for pre-commit hooks
# This script installs and configures pre-commit hooks for the project

set -e

echo "Setting up pre-commit hooks..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."
    if command -v brew &> /dev/null; then
        brew install pre-commit
    elif command -v pip3 &> /dev/null; then
        pip3 install pre-commit
    else
        echo "Please install pre-commit manually: https://pre-commit.com/#install"
        exit 1
    fi
fi

# Check if SwiftFormat is installed
if ! command -v swiftformat &> /dev/null; then
    echo "Installing SwiftFormat..."
    if command -v brew &> /dev/null; then
        brew install swiftformat
    else
        echo "Please install SwiftFormat manually: https://github.com/nicklockwood/SwiftFormat"
        exit 1
    fi
fi

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "Installing SwiftLint..."
    if command -v brew &> /dev/null; then
        brew install swiftlint
    else
        echo "Please install SwiftLint manually: https://github.com/realm/SwiftLint"
        exit 1
    fi
fi

# Install pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install

# Run pre-commit on all files
echo "Running pre-commit on all files..."
pre-commit run --all-files

echo "Setup complete! Pre-commit hooks are now active."
echo ""
echo "The following checks will run on every commit:"
echo "- Code formatting (SwiftFormat)"
echo "- Code quality (SwiftLint)"
echo "- Swift tests"
echo "- General file checks (trailing whitespace, merge conflicts, etc.)"
echo ""
echo "To run checks manually: pre-commit run --all-files"
echo "To skip hooks (not recommended): git commit --no-verify"
