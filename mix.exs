defmodule Oaks.MixProject do
  use Mix.Project

  def project do
    [
      app: :oaks,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      mod: {Oaks.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, "~> 0.26"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:mdex, "~> 0.2"},
      {:dns_cluster, "~> 0.3"},
      {:bandit, "~> 1.5"},
      {:argon2_elixir, "~> 4.0"},
      {:nimble_totp, "~> 1.0"},
      {:eqrcode, "~> 0.2"},
      {:hammer, "~> 7.0"},
      # API Documentation
      {:open_api_spex, "~> 3.18"},
      # Dev/Test tools
      {:req, "~> 0.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # Security
      {:sobelow, "~> 0.18", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [&isolate_test_db/1, "ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind oaks", "esbuild oaks"],
      "assets.deploy": [
        "tailwind oaks --minify",
        "esbuild oaks --minify",
        "phx.digest"
      ],
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "deps.unlock --unused",
        "test"
      ]
    ]
  end

  # Each `mix test` runs on its own copy of the seeded test database (item
  # b1b5). priv/oaks_test.sqlite, built by `make test-db` and CI, is only the
  # template: two runs on one file starve each other (every test holds BEGIN
  # IMMEDIATE), and `make test-db` deletes the file under a live run. Copies
  # live in _build/test/test_dbs (per checkout, gitignored) and are deleted at
  # exit; ones left by killed runs are swept after a day.
  defp isolate_test_db(_args) do
    config = Application.get_env(:oaks, Oaks.Repo)
    template = Keyword.fetch!(config, :database)
    dir = Path.join(Mix.Project.build_path(), "test_dbs")
    File.mkdir_p!(dir)
    sweep_stale_test_dbs(dir)

    run_db = Path.join(dir, "oaks_test-#{System.pid()}.sqlite")
    # A reused OS pid must not inherit a killed run's files.
    remove_db_files(run_db)

    if File.exists?(template) do
      File.cp!(template, run_db)
      wal = template <> "-wal"
      if File.exists?(wal) and File.stat!(wal).size > 0, do: File.cp!(wal, run_db <> "-wal")
    else
      Mix.shell().info("No #{Path.relative_to_cwd(template)}; run make test-db for the seeds")
    end

    Application.put_env(:oaks, Oaks.Repo, Keyword.put(config, :database, run_db),
      persistent: true
    )

    System.at_exit(fn _status -> remove_db_files(run_db) end)
  end

  defp sweep_stale_test_dbs(dir) do
    cutoff = System.os_time(:second) - 86_400

    for file <- File.ls!(dir),
        path = Path.join(dir, file),
        match?({:ok, %{mtime: mtime}} when mtime < cutoff, File.stat(path, time: :posix)) do
      File.rm(path)
    end
  end

  defp remove_db_files(db) do
    Enum.each(["", "-wal", "-shm"], &File.rm(db <> &1))
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts/core.plt",
      plt_local_path: "priv/plts/project.plt",
      plt_add_apps: [:mix, :ex_unit, :req],
      ignore_warnings: ".dialyzer_ignore.exs",
      flags: [
        :error_handling,
        :unknown
      ]
    ]
  end

  defp releases do
    [
      oaks: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
