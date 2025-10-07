defmodule Dotfiler.Config do
  @moduledoc """
  Configuration loading and management for Dotfiler.

  Supports loading configuration from TOML files with the following priority:
  1. CLI --config flag path
  2. $PWD/.dotfilerrc (project-specific)
  3. ~/.dotfilerrc (user-specific)
  4. ~/.config/dotfiler/config.toml (XDG standard)
  5. Built-in defaults
  """

  alias Dotfiler.Print

  @type config :: %{
          general: map(),
          filtering: map(),
          linking: map(),
          packages: map()
        }
  @type key_path :: [atom()]

  @default_config %{
    general: %{
      backup_dir: "~/.dotfiler_backup",
      dry_run: false,
      verbose: false
    },
    filtering: %{
      exclude: [".*", "[A-Z]*"],
      include: ["*"],
      ignore_file: ".dotfilerignore",
      use_gitignore: false
    },
    linking: %{
      backup_existing: true,
      on_conflict: "backup"
    },
    packages: %{
      auto_brew: false,
      brewfile_name: "Brewfile"
    }
  }

  @doc """
  Loads configuration from TOML files or returns defaults.

  Searches for configuration files in priority order and merges them with defaults.

  ## Parameters
    - `custom_config_path` - Optional path to a custom config file (default: nil)

  ## Returns
    - Configuration map with all settings

  ## Examples
      iex> Dotfiler.Config.load()
      # Returns default configuration

      iex> Dotfiler.Config.load("/path/to/custom.toml")
      # Loads and merges custom configuration
  """
  @spec load(String.t() | nil) :: config()
  def load(custom_config_path \\ nil) do
    config_path = find_config_file(custom_config_path)

    case config_path do
      nil ->
        @default_config

      path ->
        load_config_file(path)
    end
  end

  @doc """
  Retrieves a configuration value at the specified key path.

  ## Parameters
    - `config` - Configuration map
    - `key_path` - List of atoms representing the nested path (e.g., [:general, :backup_dir])
    - `default` - Default value if key not found (default: nil)

  ## Returns
    - The value at the key path or the default value

  ## Examples
      iex> Dotfiler.Config.get(config, [:general, :backup_dir])
      "~/.dotfiler_backup"

      iex> Dotfiler.Config.get(config, [:missing, :key], "default")
      "default"
  """
  @spec get(config(), key_path(), any()) :: any()
  def get(config, key_path, default \\ nil) do
    get_in(config, key_path) || default
  end

  @doc """
  Merges CLI options with configuration (CLI takes precedence).

  ## Parameters
    - `config` - Base configuration map
    - `cli_options` - Keyword list of CLI options

  ## Returns
    - Merged configuration map

  ## Examples
      iex> Dotfiler.Config.merge_with_cli_options(config, [dry_run: true])
      # Returns config with dry_run overridden to true
  """
  @spec merge_with_cli_options(config(), keyword()) :: config()
  def merge_with_cli_options(config, cli_options) do
    config
    |> merge_general_options(cli_options)
    |> merge_package_options(cli_options)
  end

  defp find_config_file(custom_path) do
    cond do
      custom_path ->
        # Return custom path even if it doesn't exist, let load_config_file handle the error
        custom_path

      File.exists?(".dotfilerrc") ->
        ".dotfilerrc"

      File.exists?(Path.expand("~/.dotfilerrc")) ->
        Path.expand("~/.dotfilerrc")

      File.exists?(Path.expand("~/.config/dotfiler/config.toml")) ->
        Path.expand("~/.config/dotfiler/config.toml")

      true ->
        nil
    end
  end

  defp load_config_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case TomlElixir.parse(content) do
          {:ok, parsed_config} ->
            merge_configs(@default_config, normalize_config(parsed_config))

          {:error, error} ->
            Print.failure_message(
              "Invalid TOML syntax in config file #{path}: #{inspect(error)}. Using default configuration.",
              1
            )

            @default_config
        end

      {:error, reason} ->
        Print.failure_message(
          "Could not read config file #{path}: #{reason}. Falling back to default configuration.",
          1
        )

        @default_config
    end
  end

  defp normalize_config(config) do
    config
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      try do
        atom_key = String.to_existing_atom(key)
        Map.put(acc, atom_key, normalize_section(value))
      rescue
        ArgumentError ->
          Print.failure_message("Unknown configuration section '#{key}' found in config file", 1)
          acc
      end
    end)
  end

  defp normalize_section(section) when is_map(section) do
    section
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      try do
        atom_key = String.to_existing_atom(key)
        Map.put(acc, atom_key, value)
      rescue
        ArgumentError ->
          Print.failure_message("Unknown configuration key '#{key}' found in config file", 1)
          acc
      end
    end)
  end

  defp normalize_section(value), do: value

  defp merge_configs(base, override) do
    Map.merge(base, override, fn _key, base_val, override_val ->
      if is_map(base_val) and is_map(override_val) do
        Map.merge(base_val, override_val)
      else
        override_val
      end
    end)
  end

  defp merge_general_options(config, cli_options) do
    general = config.general

    updated_general =
      general
      |> maybe_update(:dry_run, Keyword.get(cli_options, :dry_run))

    put_in(config, [:general], updated_general)
  end

  defp merge_package_options(config, cli_options) do
    packages = config.packages

    updated_packages =
      packages
      |> maybe_update(:auto_brew, Keyword.get(cli_options, :brew))

    put_in(config, [:packages], updated_packages)
  end

  defp maybe_update(map, _key, nil), do: map
  defp maybe_update(map, key, value), do: Map.put(map, key, value)
end
