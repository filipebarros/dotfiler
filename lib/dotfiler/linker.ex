defmodule Dotfiler.Linker do
  alias Dotfiler.Link

  def from_source(source \\ "") do
    {_, files} = File.ls(source)
    files
    |> Enum.filter(&filter_files(&1))
    |> Enum.each(&Link.create(source, &1))
  end

  defp filter_files(filename) do
    cond do
      String.first(filename) == "." -> false
      String.first(filename) == String.first(filename) |> String.upcase -> false
      true -> true
    end
  end
end
