defmodule Dotfiler.CLI do
  @moduledoc """
  Command-line interface for Dotfiler.

  Handles argument parsing, validation, and orchestrates the main workflow
  including dry-run mode, source directory validation, and restoration of backups.
  """

  alias Dotfiler.{Brew, Link, Print}

  def parse(args \\ []) do
    strict_options = [
      source: :string,
      brew: :boolean,
      version: :boolean,
      help: :boolean,
      dry_run: :boolean,
      restore: :boolean
    ]

    aliased_options = [
      s: :source,
      b: :brew,
      v: :version,
      h: :help,
      d: :dry_run,
      r: :restore
    ]

    {parsed, _, _} = OptionParser.parse(args, strict: strict_options, aliases: aliased_options)

    cond do
      Keyword.get(parsed, :version) -> Print.version()
      Keyword.get(parsed, :help) -> Print.help()
      Keyword.get(parsed, :restore) -> Link.restore_backups()
      Keyword.has_key?(parsed, :source) -> execute(parsed)
      true -> Print.help()
    end
  end

  def execute(parsed_options) do
    source = Keyword.get(parsed_options, :source)
    brew = Keyword.get(parsed_options, :brew, false)
    dry_run = Keyword.get(parsed_options, :dry_run, false)

    if dry_run do
      Print.warning_message("DRY RUN MODE - No changes will be made", 1)
    end

    # Validate source directory
    validate_source_directory!(source)

    if brew do
      Brew.bundle(source, dry_run)
    end

    Link.from_source(source, dry_run: dry_run)
  end

  defp validate_source_directory!(source) do
    unless File.exists?(source) do
      Print.failure_message("Source directory '#{source}' does not exist", 1)
      exit_with_error()
    end

    unless File.dir?(source) do
      Print.failure_message("'#{source}' is not a directory", 1)
      exit_with_error()
    end
  end

  defp exit_with_error do
    if Mix.env() == :test do
      raise "CLI validation failed"
    else
      System.halt(1)
    end
  end
end
