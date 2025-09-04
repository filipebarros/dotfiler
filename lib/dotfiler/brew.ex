defmodule Dotfiler.Brew do
  alias Dotfiler.Print

  def bundle(source, dry_run \\ false) do
    brewfile_path = Path.join(source, "Brewfile")

    if dry_run do
      if File.exists?(brewfile_path) do
        Print.warning_message(
          "[DRY RUN] Would install Homebrew packages from #{brewfile_path}",
          1
        )
      else
        Print.warning_message("[DRY RUN] No Brewfile found in #{source}", 1)
      end
    else
      if not File.exists?(brewfile_path) do
        Print.warning_message("No Brewfile found in #{source}, skipping Homebrew packages", 1)
      else
        Print.warning_message("Installing Homebrew packages from #{brewfile_path}", 1)

        case System.cmd("brew", ["bundle"], cd: source) do
          {_output, 0} ->
            Print.success_message("Successfully installed Homebrew packages", 2)

          {output, exit_code} ->
            Print.failure_message(
              "Failed to install Homebrew packages (exit code: #{exit_code})",
              2
            )

            if String.length(String.trim(output)) > 0 do
              Print.failure_message("Error output: #{String.trim(output)}", 2)
            end
        end
      end
    end
  end
end
