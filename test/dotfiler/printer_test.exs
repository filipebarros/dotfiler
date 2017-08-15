defmodule Dotfiler.PrinterTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "prints help menu" do
    help_message = """
    Usage:
    ./dotfiler --source [folder] [options]

    Options:
    --help      Show this help message.
    --brew      Install Homebrew
    --packages  Install Homebrew packages (Brewfile)

    Description:
    Installs dotfiles

    """

    print = fn ->
      Dotfiler.Printer.help
    end

    assert capture_io(print) == help_message
  end

  test "prints version" do
    print = fn ->
      Dotfiler.Printer.version
    end

    assert capture_io(print) == "#{Dotfiler.Mixfile.project[:version]}\n"
  end
end
