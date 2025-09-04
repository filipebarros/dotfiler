# Dotfiler

[![CI](https://github.com/filipebarros/dotfiler/actions/workflows/ci.yml/badge.svg)](https://github.com/filipebarros/dotfiler/actions/workflows/ci.yml)

A safe and powerful dotfiles management tool written in Elixir. Dotfiler creates symbolic links from your dotfiles directory to your home directory with automatic backups, dry-run preview, and complete restore functionality.

## Features

🔒 **Safety First**

- Automatic backup of existing files before symlinking
- Dry-run mode to preview changes without making them
- Complete restore system to undo all changes
- Comprehensive error handling and validation

🔧 **Smart Dotfiles Management**

- Intelligent file filtering (excludes dotfiles and uppercase files)
- Symbolic link creation from source to `~/.filename`
- Handles both files and directories

🍺 **Homebrew Integration**

- Optional Homebrew package installation from Brewfile
- Automatic Brewfile detection in source directory
- Proper error handling for missing brew or Brewfile

✨ **Developer Experience**

- Colored terminal output with clear status messages
- Comprehensive help system
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
# Preview changes without making them
./bin/dotfiler --source ~/dotfiles --dry-run

# Install dotfiles and Homebrew packages
./bin/dotfiler --source ~/dotfiles --brew

# Install dotfiles only
./bin/dotfiler --source ~/dotfiles

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
├── bashrc          # → ~/.bashrc
├── vimrc           # → ~/.vimrc
├── gitconfig       # → ~/.gitconfig
├── tmux.conf       # → ~/.tmux.conf
├── ssh/            # → ~/.ssh/ (directory)
│   └── config
├── Brewfile        # Homebrew packages (optional)
├── .hidden         # Ignored (starts with dot)
└── README          # Ignored (starts with uppercase)
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

## Changelog

### v0.1.0

- Initial release with basic symlinking functionality
- Homebrew integration
- Comprehensive safety features (backup, restore, dry-run)
- Extensive test coverage
- Git hooks for code quality
- CI/CD with GitHub Actions
