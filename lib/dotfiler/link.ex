defmodule Dotfiler.Link do
  alias Dotfiler.Print

  def create(source, filename) do
    full_path = file_path(source, filename)
    type = type(full_path)
    dotfile_path = dotfile_path(filename)

    message = String.pad_trailing("- #{type}: #{full_path} ", 80, "-")
    Print.warning_message(message)
    case File.ln_s(full_path, dotfile_path) do
      :ok ->
        message = String.pad_trailing("-- Successfully symlinked #{type} #{dotfile_path} ", 80, "-")
        Print.success_message(message)
      {:error, _} ->
        message = String.pad_trailing("-- #{type} #{dotfile_path} already exists ", 80, "-")
        Print.failure_message(message)
    end
  end

  defp file_path(source, filename) do
    "#{Path.expand(source)}/#{filename}"
  end

  defp dotfile_path(filename) do
    file_path(System.user_home, ".#{filename}")
  end

  defp type(filepath) do
    case File.dir?(filepath) do
      true -> "Folder"
      false -> "File"
    end
  end
end
