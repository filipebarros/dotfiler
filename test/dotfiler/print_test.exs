defmodule Dotfiler.PrintTest do
  use ExUnit.Case

  alias Dotfiler.Print

  import ExUnit.CaptureIO

  test "prints help menu" do
    help_message = """
    Usage:
    ./dotfiler --source [folder] [options]

    Options:
    --source, -s     Source directory containing dotfiles (required)
    --brew, -b       Install Homebrew packages from Brewfile
    --dry-run, -d    Preview changes without making them
    --restore, -r    Restore backed up files and remove symlinks
    --version, -v    Show version information
    --help, -h       Show this help message

    Description:
    Manages dotfiles by creating symlinks from source directory to home directory.
    Automatically backs up existing files before symlinking.

    Examples:
    ./dotfiler --source ~/dotfiles --brew
    ./dotfiler --source ~/dotfiles --dry-run
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
