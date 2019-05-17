defmodule Dotfiler.Link do
  alias Dotfiler.Print

  def from_source(source \\ "") do
    {_, files} = File.ls(source)
    files
    |> Enum.filter(&filter_files(&1))
    |> Enum.each(&create(source, &1))
  end

  defp filter_files(filename) do
    cond do
      String.first(filename) == "." -> false
      String.first(filename) == String.first(filename) |> String.upcase -> false
      true -> true
    end
  end

  def create(source, filename) do
    full_path = file_path(source, filename)
    type = type(full_path)
    dotfile_path = dotfile_path(filename)

    Print.warning_message("#{type}: #{full_path}", 1)
    case File.ln_s(full_path, dotfile_path) do
      :ok ->
        Print.success_message("Successfully symlinked #{type} #{dotfile_path}", 2)
      {:error, _} ->
        Print.failure_message("#{type} #{dotfile_path} already exists", 2)
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
