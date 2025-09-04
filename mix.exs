defmodule Dotfiler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dotfiler,
      version: "0.1.0",
      elixir: "~> 1.18",
      escript: escript(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def escript, do: [main_module: Dotfiler, path: "bin/dotfiler"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:meck, "~> 0.9.2", only: :test}
    ]
  end
end
