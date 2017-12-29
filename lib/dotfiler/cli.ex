defmodule Dotfiler.CLI do
  alias Dotfiler.{Print, Linker}

  def parse(args \\ []) do
    options = OptionParser.parse(args, strict: [source: :string, version: :boolean, help: :boolean], aliases: [s: :source, v: :version, h: :help])

    case options do
      {[version: true], [], []} -> Dotfiler.Print.version
      {[source: source], [], []} -> Dotfiler.Linker.from_source(source)
      {[help: true], [], []} -> Dotfiler.Print.help
    end
  end
end
