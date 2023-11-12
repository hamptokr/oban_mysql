defmodule ObanMySQL.Test.MySQLRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban, adapter: Ecto.Adapters.MyXQL
end
