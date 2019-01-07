defmodule Dotfiler.Brew do
  alias Dotfiler.Print

  def bundle(source \\ "") do
    {res, _} = System.cmd("brew", ["bundle"], cd: Path.dirname(source))
    Print.success_message("- Installed Homebrew packages --")
  end
end
