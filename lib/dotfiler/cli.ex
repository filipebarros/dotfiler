defmodule Dotfiler.CLI do
  @moduledoc """
  Command-line interface for Dotfiler.

  Handles argument parsing, validation, and orchestrates the main workflow
  including dry-run mode, source directory validation, and restoration of backups.
  """

  alias Dotfiler.{Brew, Config, ExitHandler, Link, Print}

  @type parsed_options :: keyword()
  @type config :: map()

  @doc """
  Parses command-line arguments and executes the appropriate action.

  ## Parameters
    - `args` - List of command-line arguments

  ## Returns
    - `:ok` on successful execution
    - Calls `System.halt(1)` on error (or raises in test environment)

  ## Examples
      iex> Dotfiler.CLI.parse(["--help"])
      # Displays help and returns :ok

      iex> Dotfiler.CLI.parse(["~/dotfiles", "--dry-run"])
      # Previews changes without making them
  """
  @spec parse([String.t()]) :: :ok | no_return()
  def parse(args \\ []) do
    strict_options = [
      brew: :boolean,
      version: :boolean,
      help: :boolean,
      dry_run: :boolean,
      restore: :boolean,
      list: :boolean,
      config: :string
    ]

    aliased_options = [
      b: :brew,
      v: :version,
      h: :help,
      d: :dry_run,
      r: :restore,
      l: :list,
      c: :config
    ]

    {parsed, positional, _} =
      OptionParser.parse(args, strict: strict_options, aliases: aliased_options)

    # Load configuration early
    config_path = Keyword.get(parsed, :config)
    config = Config.load(config_path)

    # Merge CLI options with config (CLI takes precedence)
    merged_config = Config.merge_with_cli_options(config, parsed)

    # Get source from first positional argument or config default
    source =
      case positional do
        [source_dir | _] -> source_dir
        _ -> Config.get(merged_config, [:general, :default_source])
      end

    # Add source to parsed options if found
    parsed_with_source = if source, do: Keyword.put(parsed, :source, source), else: parsed

    cond do
      Keyword.get(parsed, :help) -> Print.help()
      Keyword.get(parsed, :version) -> Print.version()
      Keyword.get(parsed, :restore) -> Link.restore_backups(merged_config)
      Keyword.get(parsed, :list) -> Link.list_symlinks(merged_config)
      source -> execute(parsed_with_source, merged_config)
      true -> Print.help()
    end
  end

  @doc """
  Executes the main dotfile linking workflow.

  ## Parameters
    - `parsed_options` - Keyword list of parsed CLI options
    - `config` - Optional configuration map (loads default if not provided)

  ## Returns
    - `:ok` on successful execution
    - Raises or halts on validation errors
  """
  @spec execute(parsed_options(), config() | nil) :: :ok | no_return()
  def execute(parsed_options, config \\ nil) do
    # Use config if provided, otherwise load default
    effective_config = config || Config.load()

    source = Keyword.get(parsed_options, :source)
    brew = Config.get(effective_config, [:packages, :auto_brew], false)
    dry_run = Config.get(effective_config, [:general, :dry_run], false)

    # CLI flags override config
    brew = Keyword.get(parsed_options, :brew, brew)
    dry_run = Keyword.get(parsed_options, :dry_run, dry_run)

    if dry_run do
      Print.warning_message("DRY RUN MODE - No changes will be made", 1)
    end

    # Validate source directory
    validate_source_directory!(source)

    if brew do
      Brew.bundle(source, dry_run, effective_config)
    end

    Link.from_source(source, dry_run: dry_run, config: effective_config)
  end

  defp validate_source_directory!(source) do
    if !File.exists?(source) do
      Print.failure_message(
        "Source directory '#{source}' does not exist. Please check the path and try again.",
        1
      )

      ExitHandler.exit_with_error("CLI validation failed")
    end

    if !File.dir?(source) do
      type = if File.regular?(source), do: "file", else: "item"

      Print.failure_message(
        "'#{source}' is a #{type}, not a directory. Please provide a directory containing dotfiles.",
        1
      )

      ExitHandler.exit_with_error("CLI validation failed")
    end
  end
end
