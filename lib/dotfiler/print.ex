defmodule Dotfiler.Print do
  @moduledoc """
  Output formatting and printing utilities for Dotfiler.

  Provides colored terminal output for success, failure, and warning messages,
  as well as help and version information display.
  """

  @doc """
  Prints the help message with usage information.

  ## Examples
      iex> Dotfiler.Print.help()
      # Displays usage instructions
  """
  @spec help() :: :ok
  def help do
    IO.puts("""
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
    """)
  end

  @doc """
  Prints a success message in green.

  ## Parameters
    - `message` - The message to print
    - `level` - Indentation level for visual hierarchy
  """
  @spec success_message(String.t(), non_neg_integer()) :: :ok
  def success_message(message, level) do
    print_message(message, IO.ANSI.green(), level)
  end

  @doc """
  Prints a failure message in red.

  ## Parameters
    - `message` - The message to print
    - `level` - Indentation level for visual hierarchy
  """
  @spec failure_message(String.t(), non_neg_integer()) :: :ok
  def failure_message(message, level) do
    print_message(message, IO.ANSI.red(), level)
  end

  @doc """
  Prints a warning message in yellow.

  ## Parameters
    - `message` - The message to print
    - `level` - Indentation level for visual hierarchy
  """
  @spec warning_message(String.t(), non_neg_integer()) :: :ok
  def warning_message(message, level) do
    print_message(message, IO.ANSI.yellow(), level)
  end

  @version Mix.Project.config()[:version]

  @doc """
  Prints the current version.

  ## Examples
      iex> Dotfiler.Print.version()
      # Displays version number
  """
  @spec version() :: :ok
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
