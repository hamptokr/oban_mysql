defmodule ObanMySQL.Engines.MySQL do
  @moduledoc """
  An engine for running Oban with MySQL.

  ## Usage

  Start an `Oban` instance using the `MySQL` engine:


      Oban.start_link(
        engine: ObanMySQL.Engines.MySQL,
        queues: [default: 10],
        repo: MyApp.Repo
      )
  """

  @behaviour Oban.Engine

  import Ecto.Query

  alias Ecto.Changeset
  alias Oban.Engines.Basic
  alias Oban.{Config, Engine, Job, Repo}

  @forever 60 * 60 * 24 * 365 * 99

  @impl Engine
  defdelegate init(conf, opts), to: Basic

  @impl Engine
  defdelegate put_meta(conf, meta, key, value), to: Basic

  @impl Engine
  defdelegate check_meta(conf, meta, running), to: Basic

  @impl Engine
  defdelegate refresh(conf, meta), to: Basic

  @impl Engine
  defdelegate shutdown(conf, meta), to: Basic

  @impl Engine
  def insert_job(%Config{} = conf, %Changeset{} = changeset, _opts) do
    with {:ok, job} <- fetch_unique(conf, changeset),
         {:ok, job} <- resolve_conflict(conf, job, changeset) do
      {:ok, %Job{job | conflict?: true}}
    else
      :not_found ->
        Repo.insert(conf, changeset)

      error ->
        error
    end
  end

  defp fetch_unique(conf, %{changes: %{unique: %{} = unique}} = changeset) do
    %{fields: fields, keys: keys, period: period, states: states, timestamp: timestamp} = unique

    keys = Enum.map(keys, &to_string/1)
    states = Enum.map(states, &to_string/1)
    since = seconds_from_now(min(period, @forever) * -1)

    dynamic =
      Enum.reduce(fields, true, fn
        field, acc when field in [:args, :meta] ->
          value =
            changeset
            |> Changeset.get_field(field)
            |> map_values(keys)

          if value == %{} do
            dynamic([j], field(j, ^field) == ^value and ^acc)
          else
            dynamic([j], json_contains(field(j, ^field), ^Jason.encode!(value)) and ^acc)
          end

        field, acc ->
          value = Changeset.get_field(changeset, field)

          dynamic([j], field(j, ^field) == ^value and ^acc)
      end)

    query =
      Job
      |> where([j], j.state in ^states)
      |> where([j], fragment("datetime(?) >= datetime(?)", field(j, ^timestamp), ^since))
      |> where(^dynamic)
      |> limit(1)

    case Repo.one(conf, query) do
      nil -> :not_found
      job -> {:ok, job}
    end
  end
end
