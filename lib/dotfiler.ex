defmodule Dotfiler do
  def main(args \\ []) do
    Dotfiler.CLI.parse(args)
  end
end
