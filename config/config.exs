import Config

config :logger, level: :warning

config :oban_mysql, ObanMySQL.Test.MySQLRepo,
  priv: "test/support/mysql",
  url: System.get_env("DATABASE_URL") || "mysql://root@localhost/oban_mysql_test",
  migrator: ObanMySQL.Migrations.MySQL,
  pool: Ecto.Adapters.SQL.Sandbox

config :oban_mysql,
  ecto_repos: [ObanMySQL.Test.MySQLRepo]
