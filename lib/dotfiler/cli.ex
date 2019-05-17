defmodule Dotfiler.CLI do
  alias Dotfiler.{Brew, Link, Print}

  def parse(args \\ []) do
    strict_options = [source: :string, brew: :boolean, version: :boolean, help: :boolean]
    aliased_options = [s: :source, b: :brew, v: :version, h: :help]

    options = OptionParser.parse(args, strict: strict_options, aliases: aliased_options)

    case options do
      {[source: source, brew: brew], [], []} -> execute(source, brew)
      {[version: true], [], []} -> Print.version
      {[help: true], [], []} -> Print.help
    end
  end

  def execute(source, brew \\ false) do
    if brew do
      Brew.bundle(source)
    end
    Link.from_source(source)
  end
end
