defmodule Dotfiler.CLI do
  @moduledoc """
  CLI Parser for Dotfiler
  """
  def parse(args \\ []) do
    options = OptionParser.parse(args, strict: [source: :string, version: :boolean, help: :boolean], aliases: [s: :source, v: :version, h: :help])

    case options do
      {[version: true], [], []} -> Dotfiler.Printer.version
      # {[source: source], [], []} -> IO.puts(source)
      {[help: true], [], []} -> Dotfiler.Printer.help
    end
  end
end
