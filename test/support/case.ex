defmodule ObanMySQL.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Oban.Job
  alias ObanMySQL.Integration.Worker
  alias ObanMySQL.Test.MySQLRepo

  using do
    quote do
      import ObanMySQL.Case

      alias Oban.{Config, Job}
      alias ObanMySQL.Integration.Worker
      alias ObanMySQL.Test.MySQLRepo
    end
  end

  def start_supervised_oban!(opts) do
    opts =
      opts
      |> Keyword.put_new(:name, make_ref())
      |> Keyword.put_new(:notifier, Oban.Notifiers.Isolated)
      |> Keyword.put_new(:peer, Oban.Peers.Isolated)
      |> Keyword.put_new(:stage_interval, :infinity)
      |> Keyword.put_new(:repo, MySQLRepo)
      |> Keyword.put_new(:shutdown_grace_period, 250)

    name = Keyword.fetch!(opts, :name)
    repo = Keyword.fetch!(opts, :repo)

    attach_auto_allow(repo, name)

    start_supervised!({Oban, opts})

    name
  end

  # Building

  def build(args, opts \\ []) do
    if opts[:worker] do
      Job.new(args, opts)
    else
      Worker.new(args, opts)
    end
  end

  def insert!(args, opts \\ []) do
    args
    |> build(opts)
    |> MySQLRepo.insert!()
  end

  def insert!(oban, args, opts) do
    changeset = build(args, opts)

    Oban.insert!(oban, changeset)
  end

  # Time

  def seconds_from_now(seconds) do
    DateTime.add(DateTime.utc_now(), seconds, :second)
  end

  def seconds_ago(seconds) do
    DateTime.add(DateTime.utc_now(), -seconds)
  end

  # Attaching

  defp attach_auto_allow(MySQLRepo, name) do
    telemetry_name = "oban-auto-allow-#{inspect(name)}"

    auto_allow = fn _event, _measure, %{conf: conf}, {name, repo, test_pid} ->
      if conf.name == name, do: Sandbox.allow(repo, test_pid, self())
    end

    :telemetry.attach_many(
      telemetry_name,
      [[:oban, :engine, :init, :start], [:oban, :plugin, :init]],
      auto_allow,
      {name, MySQLRepo, self()}
    )

    on_exit(name, fn -> :telemetry.detach(telemetry_name) end)
  end

  defp attach_auto_allow(_repo, _name), do: :ok
end
