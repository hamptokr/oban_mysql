defmodule Oban.Migrations.MySQLTest do
  use Oban.Case, async: false

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
    assert :ok = Ecto.Migrator.up(UnboxedMySQLRepo, 1, Migration)
    assert table_exists?()

    assert :ok = Ecto.Migrator.down(UnboxedMySQLRepo, 1, Migration)
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

    {:ok, %{rows: [[exists]]}} = UnboxedMySQLRepo.query(query)

    exists != 0
  end
end
