defmodule ObanMySQL.Migrations.MySQLTest do
  use ObanMySQL.Case, async: true

  defmodule MigrationRepo do
    @moduledoc false

    use Ecto.Repo, otp_app: :oban, adapter: Ecto.Adapters.MyXQL

    alias ObanMySQL.Test.MySQLRepo

    def init(_, _) do
      {:ok, Keyword.put(MySQLRepo.config(), :database, "priv/migration.db")}
    end
  end

  defmodule Migration do
    use Ecto.Migration

    def up do
      Oban.Migration.up()
    end

    def down do
      Oban.Migration.down()
    end
  end

  test "migrating a mysql database" do
    start_supervised!(MigrationRepo)

    assert :ok = Ecto.Migrator.up(MigrationRepo, 1, Migration)
    assert table_exists?()

    assert :ok = Ecto.Migrator.down(MigrationRepo, 1, Migration)
    refute table_exists?()
  end

  defp table_exists?() do
    query = """
    SELECT IF(
      EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE()
        AND table_name = 'oban_jobs'
      ), 1, 0
    ) AS table_exists;
    """

    {:ok, %{rows: [[exists]]}} = MigrationRepo.query(query)

    exists != 0
  end
end
