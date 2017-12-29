defmodule Dotfiler.Print do
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

  def success_message(message) do
    print_message(message, IO.ANSI.green)
  end

  def failure_message(message) do
    print_message(message, IO.ANSI.red)
  end

  def warning_message(message) do
    print_message(message, IO.ANSI.yellow)
  end

  @version Mix.Project.config[:version]
  def version do
    print_message(@version)
  end

  defp print_message(message, color) do
    IO.puts("#{color}#{message}#{IO.ANSI.default_color}")
  end

  defp print_message(message) do
    IO.puts(message)
  end
end
