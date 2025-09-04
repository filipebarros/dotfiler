defmodule Dotfiler do
  @moduledoc """
  Main entry point for the Dotfiler application.

  Dotfiler is a safe and powerful dotfiles management tool that creates
  symbolic links from a source directory to the home directory with
  automatic backups, dry-run preview, and complete restore functionality.
  """

  def main(args \\ []) do
    Dotfiler.CLI.parse(args)
  end
end
