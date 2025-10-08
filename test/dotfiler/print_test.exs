defmodule Dotfiler.PrintTest do
  use ExUnit.Case

  alias Dotfiler.Print

  import ExUnit.CaptureIO

  test "prints help menu" do
    help_message = """
    Usage:
    ./dotfiler <source_directory> [options]

    Arguments:
    <source_directory>   Directory containing dotfiles to symlink

    Options:
    --brew, -b           Install Homebrew packages from Brewfile
    --dry-run, -d        Preview changes without making them
    --restore, -r        Restore backed up files and remove symlinks
    --list, -l           List all currently managed symlinks with status
    --config, -c         Use custom configuration file
    --version, -v        Show version information
    --help, -h           Show this help message

    Description:
    Manages dotfiles by creating symlinks from source directory to home directory.
    Automatically backs up existing files before symlinking.

    Configuration files are loaded from (in priority order):
    1. --config flag path
    2. ./.dotfilerrc
    3. ~/.dotfilerrc
    4. ~/.config/dotfiler/config.toml

    Examples:
    ./dotfiler ~/dotfiles --brew
    ./dotfiler ~/dotfiles --dry-run
    ./dotfiler ~/dotfiles --config my-config.toml
    ./dotfiler --list
    ./dotfiler --restore

    """

    print = fn ->
      Print.help()
    end

    assert capture_io(print) == help_message
  end

  test "prints version" do
    print = fn ->
      Print.version()
    end

    assert capture_io(print) == "#{Dotfiler.Mixfile.project()[:version]}\n"
  end
end
