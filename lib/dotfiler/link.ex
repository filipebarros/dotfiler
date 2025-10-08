defmodule Dotfiler.Link do
  @moduledoc """
  Core dotfile symlinking functionality with backup and restore capabilities.

  Manages the creation of symbolic links from source files to home directory
  dotfiles, with automatic backup of existing files, comprehensive restore
  functionality, and support for dry-run mode to preview changes.
  """

  alias Dotfiler.{Config, ExitHandler, Filter, Print}

  @type link_options :: [dry_run: boolean(), config: map()]

  @doc """
  Creates symbolic links from all files in the source directory to the home directory.

  Files are filtered based on configuration and linked to `~/.filename`.
  Existing files are automatically backed up before creating symlinks.

  ## Parameters
    - `source` - Path to the source directory containing dotfiles
    - `opts` - Keyword list of options:
      - `:dry_run` - If true, only preview changes without making them (default: false)
      - `:config` - Configuration map (default: loads from Config.load())

  ## Returns
    - `:ok` on success
    - Raises or halts on error

  ## Examples
      iex> Dotfiler.Link.from_source("~/dotfiles")
      # Creates symlinks for all dotfiles

      iex> Dotfiler.Link.from_source("~/dotfiles", dry_run: true)
      # Previews changes without making them
  """
  @spec from_source(String.t(), link_options()) :: :ok | no_return()
  def from_source(source \\ "", opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    config = Keyword.get(opts, :config, Config.load())

    case File.ls(source) do
      {:ok, files} ->
        filter = Filter.new(config, source)

        files
        |> Enum.filter(&Filter.should_process?(filter, &1))
        |> Enum.each(&create(source, &1, dry_run, config))

      {:error, :enoent} ->
        Print.failure_message(
          "Source directory '#{source}' does not exist. Please check the path and try again.",
          1
        )

        ExitHandler.exit_with_error("Link operation failed")

      {:error, :eacces} ->
        Print.failure_message(
          "Permission denied accessing '#{source}'. Please check file permissions.",
          1
        )

        ExitHandler.exit_with_error("Link operation failed")

      {:error, reason} ->
        Print.failure_message(
          "Error reading source directory '#{source}': #{reason}. Please verify the directory is accessible.",
          1
        )

        ExitHandler.exit_with_error("Link operation failed")
    end
  end

  @doc """
  Creates a symbolic link for a single file from source to home directory.

  ## Parameters
    - `source` - Source directory path
    - `filename` - Name of the file to link
    - `dry_run` - If true, only preview the operation (default: false)
    - `config` - Configuration map (default: nil, loads default if needed)

  ## Returns
    - `:ok` on success or dry-run completion
  """
  @spec create(String.t(), String.t(), boolean(), map() | nil) :: :ok
  def create(source, filename, dry_run \\ false, config \\ nil) do
    config = config || Config.load()
    full_path = file_path(source, filename)
    type = type(full_path)
    dotfile_path = dotfile_path(filename)

    if dry_run do
      Print.warning_message("[DRY RUN] Would symlink #{type}: #{full_path} -> #{dotfile_path}", 1)

      if File.exists?(dotfile_path) do
        Print.warning_message("[DRY RUN] Would backup existing #{type} #{dotfile_path}", 2)
      end
    else
      Print.warning_message("#{type}: #{full_path}", 1)

      # Create backup if file/directory exists
      if File.exists?(dotfile_path) do
        backup_existing(dotfile_path, filename, config)
      end

      case File.ln_s(full_path, dotfile_path) do
        :ok ->
          Print.success_message("Successfully symlinked #{type} #{dotfile_path}", 2)

        {:error, :eexist} ->
          Print.failure_message(
            "#{type} #{dotfile_path} already exists. The backup may have failed. Please check manually.",
            2
          )

        {:error, reason} ->
          Print.failure_message(
            "Failed to create symlink for #{type} #{dotfile_path}: #{reason}. Check permissions and available space.",
            2
          )
      end
    end
  end

  defp file_path(source, filename) do
    "#{Path.expand(source)}/#{filename}"
  end

  defp dotfile_path(filename) do
    file_path(user_home(), ".#{filename}")
  end

  defp type(filepath) do
    case File.dir?(filepath) do
      true -> "Folder"
      false -> "File"
    end
  end

  defp backup_existing(dotfile_path, filename, config) do
    backup_dir = backup_directory(config)

    case File.mkdir_p(backup_dir) do
      :ok ->
        backup_path = get_unique_backup_path(backup_dir, filename)

        case File.rename(dotfile_path, backup_path) do
          :ok ->
            Print.success_message("Backed up existing file to #{backup_path}", 2)
            log_backup(filename, dotfile_path, backup_path, config)

          {:error, reason} ->
            Print.failure_message("Failed to backup #{dotfile_path}: #{reason}", 2)
        end

      {:error, reason} ->
        Print.failure_message("Failed to create backup directory #{backup_dir}: #{reason}", 2)
    end
  end

  defp get_unique_backup_path(backup_dir, filename) do
    base_path = Path.join(backup_dir, filename)

    if File.exists?(base_path) do
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      Path.join(backup_dir, "#{filename}.#{timestamp}")
    else
      base_path
    end
  end

  defp backup_directory(config) do
    backup_dir = Config.get(config, [:general, :backup_dir], "~/.dotfiler_backup")

    # Handle tilde expansion properly for tests by using user_home()
    if String.starts_with?(backup_dir, "~/") do
      Path.join(user_home(), String.slice(backup_dir, 2..-1//1))
    else
      Path.expand(backup_dir)
    end
  end

  defp log_backup(filename, original_path, backup_path, config) do
    log_file = Path.join(backup_directory(config), "backup.log")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    log_entry = "#{timestamp} | #{filename} | #{original_path} | #{backup_path}\n"

    File.write(log_file, log_entry, [:append])
  end

  @doc """
  Lists all currently managed symlinks with their status.

  Reads the backup log and displays each managed symlink with status indicators:
  - Valid: symlink exists and points to expected source
  - Broken: symlink target doesn't exist
  - Missing: file was backed up but symlink not found

  ## Parameters
    - `config` - Configuration map (default: nil, loads default if needed)

  ## Returns
    - `:ok` on completion

  ## Examples
      iex> Dotfiler.Link.list_symlinks()
      # Lists all managed dotfiles
  """
  @spec list_symlinks(map() | nil) :: :ok
  def list_symlinks(config \\ nil) do
    config = config || Config.load()
    backup_dir = backup_directory(config)
    log_file = Path.join(backup_dir, "backup.log")

    if File.exists?(log_file) do
      Print.warning_message("Managed Dotfiles", 1)

      entries =
        log_file
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_log_entry/1)
        |> Enum.filter(&(&1 != nil))

      if Enum.empty?(entries) do
        Print.warning_message("No dotfiles currently managed", 2)
      else
        Enum.each(entries, &display_symlink_status/1)
      end
    else
      Print.warning_message("No backup log found - no dotfiles are currently managed", 1)
    end
  end

  defp parse_log_entry(log_entry) do
    case String.split(log_entry, " | ") do
      [_timestamp, filename, original_path, backup_path] ->
        # Get the expected symlink target by reading the most recent entry for this file
        %{
          filename: filename,
          original_path: original_path,
          backup_path: backup_path
        }

      _ ->
        nil
    end
  end

  defp display_symlink_status(%{
         filename: _filename,
         original_path: original_path,
         backup_path: _backup_path
       }) do
    # Use lstat to check file without following symlinks
    case File.lstat(original_path) do
      {:ok, %{type: :symlink}} ->
        case File.read_link(original_path) do
          {:ok, target} ->
            Print.success_message("✓ #{original_path} → #{target}", 2)

          {:error, _} ->
            Print.failure_message("✗ #{original_path} (broken symlink)", 2)
        end

      {:ok, _} ->
        Print.warning_message("⚠ #{original_path} (exists but not a symlink)", 2)

      {:error, _} ->
        Print.warning_message("⚠ #{original_path} (symlink not found)", 2)
    end
  end

  @doc """
  Restores all backed up files from the backup directory.

  Processes the backup log in reverse order, removing symlinks and
  restoring original files to their original locations.

  ## Parameters
    - `config` - Configuration map (default: nil, loads default if needed)

  ## Returns
    - `:ok` on completion

  ## Examples
      iex> Dotfiler.Link.restore_backups()
      # Restores all backed up files
  """
  @spec restore_backups(map() | nil) :: :ok
  def restore_backups(config \\ nil) do
    config = config || Config.load()
    backup_dir = backup_directory(config)
    log_file = Path.join(backup_dir, "backup.log")

    if File.exists?(log_file) do
      log_file
      |> File.read!()
      |> String.split("\n", trim: true)
      # Restore in reverse order
      |> Enum.reverse()
      |> Enum.each(&restore_backup_entry/1)

      Print.success_message("Restore completed", 1)
    else
      Print.warning_message("No backup log found", 1)
    end
  end

  defp restore_backup_entry(log_entry) do
    case String.split(log_entry, " | ") do
      [_timestamp, filename, original_path, backup_path] ->
        restore_file_if_backup_exists(filename, original_path, backup_path)

      _ ->
        Print.warning_message("Invalid backup log entry: #{log_entry}", 2)
    end
  end

  defp restore_file_if_backup_exists(filename, original_path, backup_path) do
    if File.exists?(backup_path) do
      remove_existing_symlink(original_path)
      restore_original_file(filename, original_path, backup_path)
    end
  end

  defp remove_existing_symlink(original_path) do
    if File.exists?(original_path) do
      File.rm(original_path)
    end
  end

  defp restore_original_file(filename, original_path, backup_path) do
    case File.rename(backup_path, original_path) do
      :ok ->
        Print.success_message("Restored #{filename} to #{original_path}", 2)

      {:error, reason} ->
        Print.failure_message("Failed to restore #{filename}: #{reason}", 2)
    end
  end

  defp user_home do
    # Use environment variable in tests for better testability
    System.get_env("HOME") || System.user_home()
  end
end
