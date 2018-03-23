defmodule Gentry.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gentry,
      version: "0.1.0",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Generic retries with exponential backoff",
      name: "Gentry",
      source_url: "https://github.com/spreedly/gentry",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    []
  end

  defp package do
    [
      name: :gentry,
      licenses: ["MIT License"],
      maintainers: ["Kevin Lewis", "Spreedly"],
      links: %{"GitHub" => "https://github.com/spreedly/gentry"}
    ]
  end
end
