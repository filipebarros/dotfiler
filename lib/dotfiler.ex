defmodule Dotfiler do
  @moduledoc """
  Main entry point for the Dotfiler application.

  Dotfiler is a safe and powerful dotfiles management tool that creates
  symbolic links from a source directory to the home directory with
  automatic backups, dry-run preview, and complete restore functionality.
  """

  @doc """
  Main entry point for the escript.

  Parses command-line arguments and executes the appropriate action.

  ## Parameters
    - `args` - List of command-line arguments (defaults to empty list)

  ## Examples
      iex> Dotfiler.main(["--help"])
      # Displays help message
  """
  @spec main([String.t()]) :: :ok | no_return()
  def main(args \\ []) do
    Dotfiler.CLI.parse(args)
  end
end
