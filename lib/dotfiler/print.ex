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

  def success_message(message, level) do
    print_message(message, IO.ANSI.green, level)
  end

  def failure_message(message, level) do
    print_message(message, IO.ANSI.red, level)
  end

  def warning_message(message, level) do
    print_message(message, IO.ANSI.yellow, level)
  end

  @version Mix.Project.config[:version]
  def version do
    print_message(@version)
  end

  defp print_message(message, color, level) do
    " #{message} "
    |> String.pad_leading(String.length(message) + level, "-")
    |> String.pad_trailing(80, "-")
    |> colorize(color)
    |> IO.puts
  end

  defp colorize(message, color) do
    "#{color}#{message}#{IO.ANSI.default_color}"
  end

  defp print_message(message) do
    IO.puts(message)
  end
end
