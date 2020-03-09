defmodule Common.MixProject do
  use Mix.Project

  def project do
    [
      app: :common,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "e2020-Common",
      source_url: "https://github.com/e-matrix/e2020-common",
      homepage_url: "https://github.com/e-matrix/e2020",
      docs: [
        main: "Common",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:joken, "~> 2.0"},
      {:jason, "~> 1.0"}
    ]
  end
end
