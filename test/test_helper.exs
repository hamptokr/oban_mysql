Application.ensure_all_started(:myxql)

# Once patch lands
# oban = Mix.Project.deps_path()[:oban]
# Code.require_file("#{oban}/test/support/telemetry_handler.ex", __DIR__)

Code.require_file("../../oban/test/support/telemetry_handler.ex", __DIR__)
Code.require_file("../../oban/test/support/worker.ex", __DIR__)

alias Oban.Test.{MySQLRepo, UnboxedMySQLRepo}

Application.put_env(:oban_mysql, MySQLRepo,
  adapter: Ecto.Adapters.MyXQL,
  username: "root",
  database: "oban_mysql_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true,
  migrator: Oban.Migrations.MySQL
)

{:ok, _} = Ecto.Adapters.MyXQL.ensure_all_started(MySQLRepo.config(), :temporary)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.MyXQL.storage_down(MySQLRepo.config())
:ok = Ecto.Adapters.MyXQL.storage_up(MySQLRepo.config())

{:ok, _} = MySQLRepo.start_link()
{:ok, _} = UnboxedMySQLRepo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(MySQLRepo, :manual)
Process.flag(:trap_exit, true)

ExUnit.start(assert_receive_timeout: 500, exclude: [:skip])
