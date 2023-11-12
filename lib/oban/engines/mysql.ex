defmodule Oban.Engines.MySQL do
  @moduledoc """
  An engine for running Oban with MySQL.

  ## Usage

  Start an `Oban` instance using the `MySQL` engine:


      Oban.start_link(
        engine: Oban.Engines.MySQL,
        queues: [default: 10],
        repo: MyApp.Repo
      )
  """

  @behaviour Oban.Engine

  import Ecto.Query

  alias Ecto.Changeset
  alias Oban.Engines.Basic
  alias Oban.{Config, Engine, Job, Repo}

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
  def insert_job(%Config{} = conf, %Changeset{} = changeset, opts) do
    fun = fn -> insert_unique(conf, changeset, opts) end

    with {:ok, result} <- Repo.transaction(conf, fun), do: result
  end

  # Insertion

  defp insert_unique(conf, changeset, opts) do
    opts = Keyword.put(opts, :on_conflict, :nothing)

    with {:ok, query, lock_key} <- unique_query(changeset),
         :ok <- acquire_lock(conf, lock_key),
         {:ok, job} <- fetch_job(conf, query, opts),
         {:ok, job} <- resolve_conflict(conf, job, changeset, opts) do
      {:ok, %Job{job | conflict?: true}}
    else
      {:error, :locked} ->
        Changeset.apply_action(changeset, :insert)

      nil ->
        Repo.insert(conf, changeset, opts)

      error ->
        error
    end
  end

  defp resolve_conflict(conf, job, changeset, opts) do
    case Changeset.fetch_change(changeset, :replace) do
      {:ok, replace} ->
        keys = Keyword.get(replace, String.to_existing_atom(job.state), [])

        Repo.update(
          conf,
          Changeset.change(job, Map.take(changeset.changes, keys)),
          opts
        )

      :error ->
        {:ok, job}
    end
  rescue
    error in [Ecto.StaleEntryError] ->
      {:error, error}
  end

  defp unique_query(%{changes: %{unique: %{} = unique}} = changeset) do
    %{fields: fields, keys: keys, period: period, states: states, timestamp: timestamp} = unique

    keys = Enum.map(keys, &to_string/1)
    states = Enum.map(states, &to_string/1)
    dynamic = Enum.reduce(fields, true, &unique_field({changeset, &1, keys}, &2))
    lock_key = :erlang.phash2([keys, states, dynamic])

    query =
      Job
      |> where([j], j.state in ^states)
      |> since_period(period, timestamp)
      |> where(^dynamic)
      |> limit(1)

    {:ok, query, lock_key}
  end

  defp unique_field({changeset, field, keys}, acc) when field in [:args, :meta] do
    value = unique_map_values(changeset, field, keys)

    if value == %{} do
      dynamic([j], fragment("? <@ ?", field(j, ^field), ^value) and ^acc)
    else
      dynamic([j], fragment("? @> ?", field(j, ^field), ^value) and ^acc)
    end
  end

  defp unique_field({changeset, field, _}, acc) do
    value = Changeset.get_field(changeset, field)

    dynamic([j], field(j, ^field) == ^value and ^acc)
  end

  defp unique_map_values(changeset, field, keys) do
    case keys do
      [] ->
        Changeset.get_field(changeset, field)

      [_ | _] ->
        changeset
        |> Changeset.get_field(field)
        |> Map.new(fn {key, val} -> {to_string(key), val} end)
        |> Map.take(keys)
    end
  end

  defp since_period(query, :infinity, _timestamp), do: query

  defp since_period(query, period, timestamp) do
    where(query, [j], field(j, ^timestamp) >= ^seconds_from_now(-period))
  end

  defp acquire_lock(conf, base_key) do
    pref_key = :erlang.phash2(conf.prefix)
    lock_key = pref_key + base_key

    case Repo.query(conf, "SELECT pg_try_advisory_xact_lock($1)", [lock_key]) do
      {:ok, %{rows: [[true]]}} ->
        :ok

      _ ->
        {:error, :locked}
    end
  end

  defp fetch_job(conf, query, opts) do
    case Repo.one(conf, query, Keyword.put(opts, :prepare, :unnamed)) do
      nil -> nil
      job -> {:ok, job}
    end
  end

  defp seconds_from_now(seconds), do: DateTime.add(DateTime.utc_now(), seconds, :second)
end
