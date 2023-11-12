defmodule ObanMySQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_mysql,
      name: "ObanMySQL",
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:myxql, "~> 0.6"},
      {:oban, path: "../oban", only: [:dev, :test], runtime: false}
    ]
  end
end
