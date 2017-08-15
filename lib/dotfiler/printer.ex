defmodule Dotfiler.Printer do
  @moduledoc """
  Printer for Dotfiler
  """

  def help do
    IO.puts("""
    Usage:
    ./dotfiler --source [folder] [options]

    Options:
    --help      Show this help message.
    --brew      Install Homebrew
    --packages  Install Homebrew packages (Brewfile)

    Description:
    Installs dotfiles
    """)
  end

  @version Mix.Project.config[:version]
  def version do
    IO.puts(@version)
  end
end
