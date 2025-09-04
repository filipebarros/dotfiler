# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dotfiler is an Elixir CLI tool that manages dotfiles by creating symbolic links from a source directory to the home directory and optionally installing Homebrew packages. The project builds as an escript (executable Elixir script).

## Common Commands

### Build
```bash
# Build the escript executable
mix escript.build

# The built executable will be at bin/dotfiler
```

### Testing
```bash
# Run all tests
mix test

# Get dependencies first if needed
mix deps.get
```

### Development
```bash
# Install Hex and Rebar (required for fresh Elixir environments)
mix local.hex --force
mix local.rebar --force

# Get dependencies
mix deps.get

# Compile the project
mix compile

# Run the application in development
mix run

# Start an interactive Elixir session
iex -S mix
```

## Architecture

The application follows a modular Elixir structure:

- `lib/dotfiler.ex` - Main entry point that delegates to CLI module
- `lib/dotfiler/cli.ex` - Command-line argument parsing and orchestration
- `lib/dotfiler/link.ex` - Core symlinking functionality
- `lib/dotfiler/brew.ex` - Homebrew package management
- `lib/dotfiler/print.ex` - Output formatting and help messages

The CLI accepts `--source` (dotfiles directory) and optionally `--brew` (to install Homebrew packages). The main workflow is:
1. Parse command-line arguments
2. If `--brew` flag is present, run Homebrew bundle install
3. Create symbolic links from source directory to home directory

## Testing Structure

Tests are organized in `test/` directory with:
- Unit tests for individual modules (link_test.exs, print_test.exs)
- Integration tests for linking functionality (linker_test.exs)
- Test helper setup in test_helper.exs

## CI/CD

The project uses GitHub Actions (.github/workflows/ci.yml) with steps for:
- Installing dependencies (mix local.hex, mix local.rebar, mix deps.get)
- Running tests (mix test)
- Building escript (only on tag events)
- Uploading binary artifact (on tag events)

Uses Elixir 1.19 with OTP 27 on Alpine Linux container for consistency.