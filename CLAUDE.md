# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dotfiler is an Elixir CLI tool that manages dotfiles by creating symbolic links from a source directory to the home directory and optionally installing Homebrew packages. The project builds as an escript (executable Elixir script) with comprehensive safety features including backup systems, dry-run mode, and restore functionality.

## Common Commands

### Build and Development
```bash
# Build the escript executable
mix escript.build

# The built executable will be at bin/dotfiler
./bin/dotfiler --help

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Start interactive Elixir session
iex -S mix
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/dotfiler/link_test.exs

# Run specific test
mix test test/dotfiler/link_test.exs:64

# Run tests with detailed output
mix test --trace

# Format code (required before commits)
mix format

# Check if code is formatted
mix format --check-formatted

# Run code quality checks with Credo
mix credo

# Run strict code quality checks
mix credo --strict
```

### Git Hooks Setup
```bash
# Install Git hooks for automatic formatting/linting
./scripts/install-hooks.sh

# Bypass hooks temporarily
git commit --no-verify -m "wip: temporary commit"
```

## Architecture

The application follows a modular Elixir structure with comprehensive error handling and safety features:

### Core Modules
- `lib/dotfiler.ex` - Main entry point that delegates to CLI module
- `lib/dotfiler/cli.ex` - Command-line argument parsing with support for dry-run, restore, and validation
- `lib/dotfiler/link.ex` - Core symlinking functionality with backup system and restore capability
- `lib/dotfiler/brew.ex` - Homebrew package management with Brewfile detection
- `lib/dotfiler/print.ex` - Colored output formatting and help messages

### Key Features Implementation

**Safety-First Design:**
- Automatic backup system in `~/.dotfiler_backup/` before any file modifications
- Comprehensive backup logging with timestamps for restore operations
- Dry-run mode (`--dry-run`) to preview all changes without execution
- Complete restore system (`--restore`) that reverses symlinks and restores backups

**Error Handling:**
- Proper error handling for file system operations (permissions, missing directories)
- Input validation for source directories and file types
- Graceful handling of missing Brewfiles and brew command failures
- Detailed error messages with specific failure reasons

**CLI Interface:**
- Support for both long (`--source`) and short (`-s`) flags
- Conventional command structure with help, version, and restore commands
- File filtering logic that excludes dotfiles and uppercase files from source directory

### Workflow
1. **Validation**: CLI validates source directory exists and is accessible
2. **Optional Brew**: If `--brew` flag present, installs packages from Brewfile in source directory  
3. **File Discovery**: Scans source directory and filters appropriate files (excludes dotfiles, uppercase files)
4. **Backup**: Creates backups of existing files/directories that would be overwritten
5. **Linking**: Creates symbolic links from filtered source files to `~/.filename` in home directory
6. **Logging**: Records all operations for potential restore

## Testing Structure

Tests use ExUnit with comprehensive coverage:
- **Unit tests**: Individual module functionality (link_test.exs, brew_test.exs, cli_test.exs, print_test.exs)
- **Integration tests**: End-to-end workflow testing with temporary directories
- **Safety tests**: Backup creation, restore functionality, dry-run mode verification
- **Error handling tests**: Invalid inputs, permission errors, missing files

Tests mock `System.user_home()` and use temporary directories to avoid affecting the development environment.

## Git Hooks & Code Quality

The project includes automated Git hooks for code quality:

**Pre-commit Hook**: Automatically formats code, compiles with warnings as errors, runs tests, and checks for debugging statements.

**Commit Message Hook**: Enforces conventional commit format (`type(scope): description`) with supported types: feat, fix, docs, style, refactor, test, chore, ci, perf.

**Pre-push Hook**: Additional validation for protected branches including formatting verification and escript build checks.

## CI/CD

Uses GitHub Actions with Elixir 1.19 and OTP 27:
- Dependency installation and caching
- Test execution  
- Escript building (on tag events)
- Binary artifact upload (on releases)

## Development Notes

**File Filtering Logic**: The application only processes files that don't start with a dot and don't start with uppercase letters, following common dotfiles conventions.

**Backup Strategy**: All existing files are moved to `~/.dotfiler_backup/` with original names, and a `backup.log` tracks operations with timestamps for restore functionality.

**Error Recovery**: The restore command processes backup log entries in reverse order to properly undo operations, handling both files and directories.

**Homebrew Integration**: Checks for `Brewfile` existence in source directory before attempting to run `brew bundle`, with proper exit code handling and error output capture.