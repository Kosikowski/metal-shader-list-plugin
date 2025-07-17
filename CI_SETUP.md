# CI/CD Setup and Development Workflow

This document describes the CI/CD configuration and development workflow for the MetalShaderListPlugin project.

## CI/CD Pipeline

### Supported Platforms

The CI pipeline runs on the following platforms:

- **macOS**: Swift 5.9 and 6.1.2
- **iOS**: Swift 5.9 and 6.1.2
- **tvOS**: Swift 5.9 and 6.1.2
- **visionOS**: Swift 5.9 and 6.1.2
- **Linux**: Swift 5.9 and 6.1.2 (Ubuntu 22.04)
- **Windows**: Swift 5.9 and 6.1.2

### CI Jobs

1. **Build Jobs**: Build and test the project on each platform
2. **Code Quality**: Run SwiftFormat, SwiftLint, and other code quality checks
3. **Package Validation**: Validate Swift package structure and dependencies
4. **Release**: Create GitHub releases when tags are pushed

### Triggers

- **Push to main**: Runs all CI jobs
- **Pull Request**: Runs all CI jobs
- **Tag push (v*)**: Runs all CI jobs + creates release

## Local Development Setup

### Prerequisites

- Swift 5.9 or later
- Xcode 16+ (for Apple platform development)
- Homebrew (for installing tools)

### Setup Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/mateuszkosikowski/MetalShaderListPlugin.git
   cd MetalShaderListPlugin
   ```

2. **Install development tools**:
   ```bash
   # Install SwiftFormat
   brew install swiftformat

   # Install SwiftLint
   brew install swiftlint

   # Install pre-commit
   brew install pre-commit
   ```

3. **Setup pre-commit hooks**:
   ```bash
   ./scripts/setup-hooks.sh
   ```

### Development Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and commit:
   ```bash
   git add .
   git commit -m "Your commit message"
   ```
   The pre-commit hooks will automatically run and format your code.

3. **Run tests locally**:
   ```bash
   swift test
   ```

4. **Run code quality checks**:
   ```bash
   # Format code
   swiftformat --config .swiftformat Sources/ Tests/

   # Lint code
   swiftlint lint

   # Run all pre-commit checks
   pre-commit run --all-files
   ```

5. **Push and create a PR**:
   ```bash
   git push origin feature/your-feature-name
   ```

## Code Quality Tools

### SwiftFormat

- **Configuration**: `.swiftformat`
- **Purpose**: Automatic code formatting
- **Usage**: `swiftformat --config .swiftformat Sources/ Tests/`

### SwiftLint

- **Configuration**: `.swiftlint.yml`
- **Purpose**: Code quality and style enforcement
- **Usage**: `swiftlint lint`

### Pre-commit Hooks

- **Configuration**: `.pre-commit-config.yaml`
- **Purpose**: Automated checks before commits
- **Checks**:
  - Code formatting (SwiftFormat)
  - Code quality (SwiftLint)
  - Swift tests
  - General file checks (trailing whitespace, merge conflicts, etc.)

## Release Process

1. **Create a tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **CI will automatically**:
   - Run all tests on all platforms
   - Run code quality checks
   - Create a GitHub release with release notes

## Troubleshooting

### Pre-commit Hooks Not Running

If pre-commit hooks are not running:

```bash
# Reinstall hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

### SwiftFormat Issues

If SwiftFormat is not formatting correctly:

```bash
# Check configuration
swiftformat --lint --config .swiftformat Sources/ Tests/

# Format manually
swiftformat --config .swiftformat Sources/ Tests/
```

### SwiftLint Issues

If SwiftLint is reporting issues:

```bash
# Run linting
swiftlint lint

# Auto-fix issues (if possible)
swiftlint --fix
```

## CI/CD Configuration Files

- `.github/workflows/ci.yml`: Main CI configuration
- `.github/dependabot.yml`: Automatic dependency updates
- `.swiftformat`: SwiftFormat configuration
- `.swiftlint.yml`: SwiftLint configuration
- `.pre-commit-config.yaml`: Pre-commit hooks configuration
- `scripts/setup-hooks.sh`: Setup script for development environment
