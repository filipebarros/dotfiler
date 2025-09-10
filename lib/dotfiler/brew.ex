defmodule Dotfiler.Brew do
  @moduledoc """
  Homebrew package management integration.

  Provides functionality to install Homebrew packages from a Brewfile
  located in the source directory, with support for dry-run mode and
  proper error handling for missing Brewfiles or brew command failures.
  """

  alias Dotfiler.{Config, Print}

  @doc """
  Installs Homebrew packages from a Brewfile in the source directory.

  Looks for a Brewfile in the source directory and runs `brew bundle` to install packages.
  The Brewfile name can be customized via configuration.

  ## Parameters
    - `source` - Directory containing the Brewfile
    - `dry_run` - If true, only preview the operation (default: false)
    - `config` - Configuration map (default: nil, loads default if needed)

  ## Returns
    - `:ok` on success or when no Brewfile exists

  ## Examples
      iex> Dotfiler.Brew.bundle("~/dotfiles")
      # Installs packages from ~/dotfiles/Brewfile

      iex> Dotfiler.Brew.bundle("~/dotfiles", true)
      # Previews Brewfile installation
  """
  @spec bundle(String.t(), boolean(), map() | nil) :: :ok
  def bundle(source, dry_run \\ false, config \\ nil) do
    config = config || Config.load()
    brewfile_name = Config.get(config, [:packages, :brewfile_name], "Brewfile")
    brewfile_path = Path.join(source, brewfile_name)

    if dry_run do
      handle_dry_run(brewfile_path, source)
    else
      handle_bundle_installation(brewfile_path, source)
    end
  end

  defp handle_dry_run(brewfile_path, source) do
    if File.exists?(brewfile_path) do
      Print.warning_message(
        "[DRY RUN] Would install Homebrew packages from #{brewfile_path}",
        1
      )
    else
      Print.warning_message("[DRY RUN] No Brewfile found in #{source}", 1)
    end
  end

  defp handle_bundle_installation(brewfile_path, source) do
    if File.exists?(brewfile_path) do
      execute_brew_bundle(brewfile_path, source)
    else
      Print.warning_message("No Brewfile found in #{source}, skipping Homebrew packages", 1)
    end
  end

  defp execute_brew_bundle(brewfile_path, source) do
    Print.warning_message("Installing Homebrew packages from #{brewfile_path}", 1)

    try do
      case System.cmd("brew", ["bundle"], cd: source) do
        {_output, 0} ->
          Print.success_message("Successfully installed Homebrew packages", 2)

        {output, exit_code} ->
          handle_brew_error(output, exit_code)
      end
    rescue
      ErlangError ->
        Print.failure_message(
          "Homebrew (brew) command not found. Please install Homebrew first.",
          2
        )
    end
  end

  defp handle_brew_error(output, exit_code) do
    Print.failure_message(
      "Failed to install Homebrew packages (exit code: #{exit_code})",
      2
    )

    if String.length(String.trim(output)) > 0 do
      Print.failure_message("Error output: #{String.trim(output)}", 2)
    end
  end
end
