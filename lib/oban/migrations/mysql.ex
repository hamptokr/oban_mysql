defmodule Oban.Migrations.MySQL do
  @moduledoc false

  @behaviour Oban.Migration

  use Ecto.Migration

  @impl Oban.Migration
  def up(_opts) do
    create_if_not_exists table(:oban_jobs, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:state, :string, null: false, default: fragment("('available')"))
      add(:queue, :string, null: false, default: fragment("('default')"))
      add(:worker, :text, null: false)
      add(:args, :json, null: false, default: %{})
      add(:meta, :json, null: false, default: %{})
      add(:tags, :json, null: false, default: fragment("('[]')"))
      add(:errors, :json, null: false, default: fragment("('[]')"))
      add(:attempt, :integer, null: false, default: 0)
      add(:max_attempts, :integer, null: false, default: 20)
      add(:priority, :integer, null: false, default: 0)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("CURRENT_TIMESTAMP(6)")
      )

      add(:scheduled_at, :utc_datetime_usec,
        null: false,
        default: fragment("CURRENT_TIMESTAMP(6)")
      )

      add(:attempted_at, :utc_datetime_usec)
      add(:attempted_by, :json, null: false, default: fragment("('[]')"))

      add(:cancelled_at, :utc_datetime_usec)
      add(:completed_at, :utc_datetime_usec)
      add(:discarded_at, :utc_datetime_usec)
    end

    create(
      index(:oban_jobs, [
        "state(255)",
        "queue(255)",
        :priority,
        :scheduled_at,
        :id
      ])
    )

    :ok
  end

  @impl Oban.Migration
  def down(_opts) do
    drop_if_exists(table(:oban_jobs))

    :ok
  end

  @impl Oban.Migration
  def migrated_version(_opts), do: 0
end
