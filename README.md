# Dotfiler

[![CI](https://github.com/filipebarros/dotfiler/actions/workflows/ci.yml/badge.svg)](https://github.com/filipebarros/dotfiler/actions/workflows/ci.yml)
[![Elixir Version](https://img.shields.io/badge/elixir-~%3E%201.18-purple.svg)](https://elixir-lang.org)

A safe and powerful dotfiles management tool written in Elixir. Dotfiler creates symbolic links from your dotfiles directory to your home directory with automatic backups, dry-run preview, and complete restore functionality.

## Features

🔒 **Safety First**

- Automatic backup of existing files before symlinking
- Dry-run mode to preview changes without making them
- Complete restore system to undo all changes
- Comprehensive error handling and validation

🔧 **Smart Dotfiles Management**

- Advanced filtering engine with `.dotfilerignore` and `.gitignore` support
- Gitignore-style pattern matching (wildcards, negation, directory patterns)
- Customizable include/exclude patterns via TOML configuration
- Symbolic link creation from source to `~/.filename`
- Handles both files and directories

⚙️ **Flexible Configuration**

- TOML-based configuration system
- Multiple configuration file locations (project, user, XDG)
- CLI options override configuration files
- Customizable backup directory, Brewfile name, and filtering rules

🍺 **Homebrew Integration**

- Optional Homebrew package installation from Brewfile
- Automatic Brewfile detection in source directory
- Configurable Brewfile name
- Proper error handling for missing brew or Brewfile

✨ **Developer Experience**

- Colored terminal output with clear status messages
- Comprehensive help system with examples
- Full type specifications and documentation
- Git hooks for code quality and conventional commits

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/filipebarros/dotfiler.git
cd dotfiler

# Install dependencies and build
mix deps.get
mix escript.build

# The executable will be created at bin/dotfiler
```

## Usage

### Basic Commands

```bash
# Install dotfiles (using positional argument)
./bin/dotfiler ~/dotfiles

# Or use --source flag
./bin/dotfiler --source ~/dotfiles

# Preview changes without making them
./bin/dotfiler ~/dotfiles --dry-run

# Install dotfiles and Homebrew packages
./bin/dotfiler ~/dotfiles --brew

# Restore all backed up files and remove symlinks
./bin/dotfiler --restore

# Show help
./bin/dotfiler --help

# Show version
./bin/dotfiler --version
```

### Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--source DIR` | `-s` | Source directory containing dotfiles (required) |
| `--brew` | `-b` | Install Homebrew packages from Brewfile |
| `--dry-run` | `-d` | Preview changes without making them |
| `--restore` | `-r` | Restore backed up files and remove symlinks |
| `--version` | `-v` | Show version information |
| `--help` | `-h` | Show help message |

### Example Dotfiles Structure

```
~/dotfiles/
├── bashrc              # → ~/.bashrc
├── vimrc               # → ~/.vimrc
├── gitconfig           # → ~/.gitconfig
├── tmux.conf           # → ~/.tmux.conf
├── ssh/                # → ~/.ssh/ (directory)
│   └── config
├── Brewfile            # Homebrew packages (optional)
├── .dotfilerignore     # Custom ignore patterns (optional)
├── .gitignore          # Respect existing gitignore (optional)
├── .dotfilerrc         # Project-specific config (optional)
├── .hidden             # Ignored (starts with dot)
└── README              # Ignored (starts with uppercase)
```

### Configuration

Dotfiler supports TOML configuration files in multiple locations (priority order):

1. Custom path via `--config` flag
2. `$PWD/.dotfilerrc` (project-specific)
3. `~/.dotfilerrc` (user-specific)
4. `~/.config/dotfiler/config.toml` (XDG standard)

**Example configuration** (`~/.dotfilerrc`):

```toml
[general]
backup_dir = "~/.dotfiler_backup"
dry_run = false

[filtering]
# Include patterns (default: ["*"])
include = ["*.conf", "*.rc", "*.sh"]

# Exclude patterns (default: [".*", "[A-Z]*"])
exclude = ["*.tmp", "*.log"]

# Use .gitignore patterns (default: false)
use_gitignore = true

# Custom ignore file name (default: ".dotfilerignore")
ignore_file = ".dotfilerignore"

[linking]
backup_enabled = true

[packages]
brewfile_name = "Brewfile"
```

**`.dotfilerignore` file** (gitignore-style patterns):

```gitignore
# Ignore temp files
*.tmp
*.log

# Ignore cache directories
cache/
.cache/

# But keep important files
!important.log

# Root-only patterns
/local-config
```

## Safety Features

### Automatic Backups

Before creating any symlinks, Dotfiler automatically backs up existing files:

```
~/.dotfiler_backup/
├── bashrc          # Original ~/.bashrc
├── vimrc           # Original ~/.vimrc
├── backup.log      # Timestamp log of all operations
└── ...
```

### Dry Run Mode

Preview exactly what changes will be made:

```bash
./bin/dotfiler --source ~/dotfiles --dry-run
```

Output:

```
DRY RUN MODE - No changes will be made
[DRY RUN] Would symlink File: /Users/user/dotfiles/bashrc → ~/.bashrc
[DRY RUN] Would backup existing File ~/.bashrc
[DRY RUN] Would install Homebrew packages from ~/dotfiles/Brewfile
```

### Complete Restore

Undo all changes and restore original files:

```bash
./bin/dotfiler --restore
```

This will:

- Remove all symlinks created by Dotfiler
- Restore original files from backup directory
- Preserve the backup log for reference

## Development

### Prerequisites

- Elixir 1.18+ with OTP 27+
- Git (for development workflow)

### Setup

```bash
# Clone and setup
git clone https://github.com/filipebarros/dotfiler.git
cd dotfiler

# Install dependencies
mix deps.get

# Install Git hooks (optional but recommended)
./scripts/install-hooks.sh

# Run tests
mix test

# Format code
mix format

# Build executable
mix escript.build
```

### Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/dotfiler/link_test.exs

# Run with detailed output
mix test --trace

# Run specific test
mix test test/dotfiler/link_test.exs:64
```

### Code Quality

```bash
# Run static code analysis
mix credo

# Run strict Credo checks
mix credo --strict

# Run type checking with Dialyzer (first run builds PLT, takes ~5-10 min)
mix dialyzer

# Check code formatting
mix format --check-formatted

# Generate documentation
mix docs
# Opens doc/index.html
```

### Git Hooks

The project includes automated Git hooks for code quality:

- **Pre-commit**: Formats code, runs tests, checks for issues
- **Commit-msg**: Enforces conventional commit messages
- **Pre-push**: Additional validation for protected branches

Install with: `./scripts/install-hooks.sh`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Make your changes with tests
4. Ensure code is formatted (`mix format`)
5. Commit with conventional format (`git commit -m 'feat: add amazing feature'`)
6. Push to your branch (`git push origin feat/amazing-feature`)
7. Open a Pull Request

### Commit Message Format

Use conventional commits:

- `feat(scope): add new feature`
- `fix(scope): fix bug`
- `docs: update documentation`
- `test: add tests`
- `refactor: improve code structure`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Architecture

Dotfiler is built with a modular architecture:

- **`Dotfiler`** - Main entry point
- **`Dotfiler.CLI`** - Command-line argument parsing and orchestration
- **`Dotfiler.Link`** - Core symlinking logic with backup/restore
- **`Dotfiler.Filter`** - Advanced filtering engine (gitignore-style patterns)
- **`Dotfiler.Config`** - TOML configuration loading and management
- **`Dotfiler.Brew`** - Homebrew integration
- **`Dotfiler.Print`** - Colored terminal output
- **`Dotfiler.ExitHandler`** - Process exit handling (test-friendly)

All modules have comprehensive type specifications (`@spec`) and documentation (`@doc`).

## Changelog

### v0.1.0

**Core Features:**
- Safe symbolic link creation with automatic backups
- Complete restore system to undo all changes
- Dry-run mode for previewing changes
- Homebrew integration with Brewfile support

**Advanced Filtering:**
- `.dotfilerignore` support with gitignore-style patterns
- `.gitignore` integration (optional)
- Wildcard patterns (`*`, `?`)
- Negation patterns (`!important.conf`)
- Directory patterns (`cache/`)
- Root-relative patterns (`/local-only`)

**Configuration System:**
- TOML-based configuration
- Multiple file locations (project, user, XDG)
- CLI options override configuration
- Customizable filtering, backup, and package settings

**Developer Tools:**
- Full type specifications (Dialyzer-clean)
- Comprehensive documentation with ExDoc
- 120+ tests with 95%+ coverage
- Git hooks for code quality
- CI/CD with format checking, Credo, and Dialyzer

**Quality Assurance:**
- Static analysis with Credo
- Type checking with Dialyzer
- Automated code formatting
- Conventional commit enforcement
