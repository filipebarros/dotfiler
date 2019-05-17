defmodule Dotfiler.Brew do
  alias Dotfiler.Print

  def bundle(source) do
    {res, code} = System.cmd("brew", ["bundle"], cd: source)

    if code != 1 do
      Print.failure_message("Failed to install Homebrew packages", 1)
    else
      Print.success_message("Installed Homebrew packages", 1)
    end
  end
end
