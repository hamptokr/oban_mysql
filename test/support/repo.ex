defmodule Oban.Test.MySQLRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban_mysql, adapter: Ecto.Adapters.MyXQL
end

defmodule Oban.Test.UnboxedMySQLRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :oban,
    adapter: Ecto.Adapters.MyXQL

  def init(_, _) do
    config = Oban.Test.MySQLRepo.config()

    {:ok, Keyword.delete(config, :pool)}
  end
end
