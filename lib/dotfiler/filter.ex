defmodule Dotfiler.Filter do
  @moduledoc """
  Advanced filtering engine for dotfiles.

  Supports:

  - Include/exclude pattern matching
  - .dotfilerignore file parsing
  - .gitignore file support
  - Gitignore-style pattern matching
  """

  alias Dotfiler.{Config, Print}

  @type t :: %__MODULE__{
          config: map(),
          include_patterns: [String.t()],
          exclude_patterns: [String.t()],
          ignore_patterns: list(),
          source_dir: String.t()
        }

  defstruct [
    :config,
    :include_patterns,
    :exclude_patterns,
    :ignore_patterns,
    :source_dir
  ]

  @doc """
  Creates a new Filter struct with loaded ignore patterns.

  ## Parameters
    - `config` - Configuration map containing filtering rules
    - `source_dir` - Source directory to load ignore files from

  ## Returns
    - Filter struct ready for file filtering

  ## Examples
      iex> Dotfiler.Filter.new(config, "~/dotfiles")
      %Dotfiler.Filter{...}
  """
  @spec new(map(), String.t()) :: t()
  def new(config, source_dir) do
    include_patterns = Config.get(config, [:filtering, :include], ["*"])
    exclude_patterns = Config.get(config, [:filtering, :exclude], [".*", "[A-Z]*"])

    ignore_patterns = load_ignore_patterns(config, source_dir)

    %__MODULE__{
      config: config,
      include_patterns: include_patterns,
      exclude_patterns: exclude_patterns,
      ignore_patterns: ignore_patterns,
      source_dir: source_dir
    }
  end

  @doc """
  Determines if a file should be processed based on filtering rules.

  Applies include/exclude patterns and ignore file rules to determine
  if a file should be symlinked.

  ## Parameters
    - `filter` - Filter struct with loaded patterns
    - `filename` - Name of the file to check

  ## Returns
    - `true` if file should be processed
    - `false` if file should be ignored

  ## Examples
      iex> Dotfiler.Filter.should_process?(filter, "bashrc")
      true

      iex> Dotfiler.Filter.should_process?(filter, ".hidden")
      false
  """
  @spec should_process?(t(), String.t()) :: boolean()
  def should_process?(filter, filename) do
    cond do
      filename == "" -> false
      matches_ignore_patterns?(filter.ignore_patterns, filename) -> false
      not matches_include_patterns?(filter.include_patterns, filename) -> false
      matches_exclude_patterns?(filter.exclude_patterns, filename) -> false
      true -> true
    end
  end

  defp load_ignore_patterns(config, source_dir) do
    patterns = []

    # Load .dotfilerignore if configured
    ignore_file = Config.get(config, [:filtering, :ignore_file], ".dotfilerignore")

    patterns =
      if ignore_file do
        patterns ++ load_ignore_file(source_dir, ignore_file)
      else
        patterns
      end

    # Load .gitignore if configured
    use_gitignore = Config.get(config, [:filtering, :use_gitignore], false)

    patterns =
      if use_gitignore do
        patterns ++ load_ignore_file(source_dir, ".gitignore")
      else
        patterns
      end

    patterns
  end

  defp load_ignore_file(source_dir, filename) do
    ignore_path = Path.join(source_dir, filename)

    if File.exists?(ignore_path) do
      case File.read(ignore_path) do
        {:ok, content} ->
          Print.success_message("Loaded ignore patterns from #{filename}", 2)
          parse_ignore_content(content)

        {:error, reason} ->
          Print.warning_message("Could not read #{filename}: #{reason}", 2)
          []
      end
    else
      []
    end
  end

  defp parse_ignore_content(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.map(&parse_ignore_pattern/1)
  end

  defp parse_ignore_pattern(pattern) do
    cond do
      String.starts_with?(pattern, "!") ->
        # Negation pattern - recursively parse the pattern after '!' to preserve its type
        inner_pattern = String.slice(pattern, 1..-1//1)
        {:negate, parse_ignore_pattern(inner_pattern)}

      String.starts_with?(pattern, "/") ->
        # Root-relative pattern (check before glob to handle /root* correctly)
        {:root_relative, String.slice(pattern, 1..-1//1)}

      String.ends_with?(pattern, "/") ->
        # Directory pattern
        {:directory, String.slice(pattern, 0..-2//1)}

      String.contains?(pattern, "*") or String.contains?(pattern, "?") ->
        # Glob pattern
        {:glob, pattern}

      true ->
        # Simple pattern
        {:simple, pattern}
    end
  end

  defp matches_ignore_patterns?(patterns, filename) do
    # Check if file should be ignored based on .dotfilerignore/.gitignore patterns
    {negations, normal_patterns} =
      Enum.split_with(patterns, fn
        {:negate, _} -> true
        _ -> false
      end)

    # First check if any normal pattern matches (would exclude)
    excluded = Enum.any?(normal_patterns, &pattern_matches?(&1, filename))

    # Then check if any negation pattern matches (would include back)
    if excluded do
      not Enum.any?(negations, fn {:negate, inner_pattern} ->
        # Use the inner pattern with its original type preserved
        pattern_matches?(inner_pattern, filename)
      end)
    else
      false
    end
  end

  defp matches_include_patterns?(patterns, filename) do
    # If patterns include "*", include everything by default
    if "*" in patterns do
      true
    else
      Enum.any?(patterns, &simple_pattern_matches?(&1, filename))
    end
  end

  defp matches_exclude_patterns?(patterns, filename) do
    Enum.any?(patterns, &simple_pattern_matches?(&1, filename))
  end

  defp pattern_matches?({:simple, pattern}, filename) do
    simple_pattern_matches?(pattern, filename)
  end

  defp pattern_matches?({:glob, pattern}, filename) do
    # Convert glob pattern to regex
    regex_pattern =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("*", ".*")
      |> String.replace("?", ".")

    String.match?(filename, ~r/^#{regex_pattern}$/)
  end

  defp pattern_matches?({:directory, pattern}, filename) do
    # For directory patterns, we don't have directory info in this context
    # So we treat it as a simple pattern match
    simple_pattern_matches?(pattern, filename)
  end

  defp pattern_matches?({:root_relative, pattern}, filename) do
    # Root-relative patterns match from the beginning
    # Check if the pattern contains wildcards
    if String.contains?(pattern, "*") or String.contains?(pattern, "?") do
      # Treat as a glob pattern that must match from the start
      regex_pattern =
        pattern
        |> String.replace(".", "\\.")
        |> String.replace("*", ".*")
        |> String.replace("?", ".")

      String.match?(filename, ~r/^#{regex_pattern}$/)
    else
      String.starts_with?(filename, pattern)
    end
  end

  defp simple_pattern_matches?(pattern, filename) do
    case pattern do
      ".*" -> starts_with_dot?(filename)
      "[A-Z]*" -> starts_with_uppercase?(filename)
      _ -> match_pattern(pattern, filename)
    end
  end

  defp starts_with_dot?(filename), do: String.starts_with?(filename, ".")

  defp starts_with_uppercase?(filename), do: String.match?(filename, ~r/^[A-Z]/)

  defp match_pattern(pattern, filename) do
    if has_wildcards?(pattern) do
      wildcard_match(pattern, filename)
    else
      exact_or_substring_match(pattern, filename)
    end
  end

  defp has_wildcards?(pattern) do
    String.contains?(pattern, "*") or String.contains?(pattern, "?")
  end

  defp wildcard_match(pattern, filename) do
    if String.starts_with?(pattern, "*") do
      star_prefix_match(pattern, filename)
    else
      regex_wildcard_match(pattern, filename)
    end
  end

  defp star_prefix_match(pattern, filename) do
    suffix = String.slice(pattern, 1..-1//1)
    String.ends_with?(filename, suffix)
  end

  defp regex_wildcard_match(pattern, filename) do
    regex_pattern =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("*", ".*")
      |> String.replace("?", ".")

    String.match?(filename, ~r/^#{regex_pattern}$/)
  end

  defp exact_or_substring_match(pattern, filename) do
    filename == pattern or String.contains?(filename, pattern)
  end
end
