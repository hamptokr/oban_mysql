Application.ensure_all_started([:myxql, :oban])

ObanMySQL.Test.MySQLRepo.start_link()
ExUnit.start(assert_receive_timeout: 500, exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(ObanMySQL.Test.MySQLRepo, :manual)
