defmodule Dotfiler.Print do
  @moduledoc """
  Printer for Dotfiler
  """

  def help do
    IO.puts("""
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
    """)
  end

  def success_message(message, level) do
    print_message(message, IO.ANSI.green(), level)
  end

  def failure_message(message, level) do
    print_message(message, IO.ANSI.red(), level)
  end

  def warning_message(message, level) do
    print_message(message, IO.ANSI.yellow(), level)
  end

  @version Mix.Project.config()[:version]
  def version do
    print_message(@version)
  end

  defp print_message(message, color, level) do
    " #{message} "
    |> String.pad_leading(String.length(message) + level, "-")
    |> String.pad_trailing(80, "-")
    |> colorize(color)
    |> IO.puts()
  end

  defp colorize(message, color) do
    "#{color}#{message}#{IO.ANSI.default_color()}"
  end

  defp print_message(message) do
    IO.puts(message)
  end
end
