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

  alias Oban.Engines.Basic
  alias Oban.Engine

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
  defdelegate insert_job(conf, changeset, opts), to: Basic

  @impl Engine
  defdelegate insert_all_jobs(conf, changesets, opts), to: Basic

  @impl Engine
  defdelegate fetch_jobs(conf, meta, running), to: Basic

  @impl Engine
  defdelegate stage_jobs(conf, queryable, opts), to: Basic

  @impl Engine
  defdelegate prune_jobs(conf, queryable, opts), to: Basic

  @impl Engine
  defdelegate complete_job(conf, job), to: Basic

  @impl Engine
  defdelegate discard_job(conf, job), to: Basic

  @impl Engine
  defdelegate error_job(conf, job, seconds), to: Basic

  @impl Engine
  defdelegate snooze_job(conf, job, seconds), to: Basic

  @impl Engine
  defdelegate cancel_job(conf, job), to: Basic

  @impl Engine
  defdelegate cancel_all_jobs(conf, queryable), to: Basic

  @impl Engine
  defdelegate retry_job(conf, job), to: Basic

  @impl Engine
  defdelegate retry_all_jobs(conf, queryable), to: Basic
end
