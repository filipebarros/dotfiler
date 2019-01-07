defmodule Dotfiler.CLI do
  alias Dotfiler.{Brew, Link, Print}

  def parse(args \\ []) do
    strict_options = [source: :string, brew: :boolean, version: :boolean, help: :boolean]
    aliased_options = [s: :source, b: :brew, v: :version, h: :help]

    options = OptionParser.parse(args, strict: strict_options, aliases: aliased_options)

    case options do
      {[source: source], [], []} -> Link.from_source(source)
      {[source: source, brew: true], [], []} -> Brew.bundle(source)
      {[version: true], [], []} -> Print.version
      {[help: true], [], []} -> Print.help
    end
  end
end
