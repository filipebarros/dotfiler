defmodule Dotfiler.Link do
  @moduledoc """
  Core dotfile symlinking functionality with backup and restore capabilities.

  Manages the creation of symbolic links from source files to home directory
  dotfiles, with automatic backup of existing files, comprehensive restore
  functionality, and support for dry-run mode to preview changes.
  """

  alias Dotfiler.Print

  def from_source(source \\ "", opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    case File.ls(source) do
      {:ok, files} ->
        files
        |> Enum.filter(&filter_files(&1))
        |> Enum.each(&create(source, &1, dry_run))

      {:error, :enoent} ->
        Print.failure_message("Source directory '#{source}' does not exist", 1)
        exit_with_error()

      {:error, :eacces} ->
        Print.failure_message("Permission denied accessing '#{source}'", 1)
        exit_with_error()

      {:error, reason} ->
        Print.failure_message("Error reading source directory: #{reason}", 1)
        exit_with_error()
    end
  end

  defp filter_files(filename) do
    cond do
      String.first(filename) == "." -> false
      String.first(filename) == String.first(filename) |> String.upcase() -> false
      true -> true
    end
  end

  def create(source, filename, dry_run \\ false) do
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
        backup_existing(dotfile_path, filename)
      end

      case File.ln_s(full_path, dotfile_path) do
        :ok ->
          Print.success_message("Successfully symlinked #{type} #{dotfile_path}", 2)

        {:error, :eexist} ->
          Print.failure_message("#{type} #{dotfile_path} already exists (backup failed?)", 2)

        {:error, reason} ->
          Print.failure_message("Failed to symlink #{type} #{dotfile_path}: #{reason}", 2)
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

  defp backup_existing(dotfile_path, filename) do
    backup_dir = backup_directory()
    File.mkdir_p!(backup_dir)

    backup_path = Path.join(backup_dir, filename)

    case File.rename(dotfile_path, backup_path) do
      :ok ->
        Print.success_message("Backed up existing file to #{backup_path}", 2)
        log_backup(filename, dotfile_path, backup_path)

      {:error, reason} ->
        Print.failure_message("Failed to backup #{dotfile_path}: #{reason}", 2)
    end
  end

  defp backup_directory do
    Path.join(user_home(), ".dotfiler_backup")
  end

  defp log_backup(filename, original_path, backup_path) do
    log_file = Path.join(backup_directory(), "backup.log")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    log_entry = "#{timestamp} | #{filename} | #{original_path} | #{backup_path}\n"

    File.write(log_file, log_entry, [:append])
  end

  def restore_backups do
    backup_dir = backup_directory()
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

  defp exit_with_error do
    if Mix.env() == :test do
      raise "Link operation failed"
    else
      System.halt(1)
    end
  end
end
