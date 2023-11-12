defmodule ObanMySQL.Engines.MySQLTest do
  use ObanMySQL.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias ObanMySQL.TelemetryHandler

  @engine ObanMySQL.Engines.MySQL
  @repo ObanMySQL.Test.MySQLRepo

  describe "insert/2" do
    setup :start_supervised_oban

    test "inserting a single job", %{name: name} do
      TelemetryHandler.attach_events()

      assert {:ok, job} = Oban.insert(name, Worker.new(%{ref: 1}))

      assert_receive {:event, [:insert_job, :stop], _, %{job: ^job, opts: []}}
    end

    @tag :unique
    test "inserting a job with uniqueness applied", %{name: name} do
      changeset = Worker.new(%{ref: 1}, unique: [period: 60])

      assert {:ok, job_1} = Oban.insert(name, changeset)
      assert {:ok, job_2} = Oban.insert(name, changeset)

      refute job_1.conflict?
      assert job_2.conflict?
      assert job_1.id == job_2.id
    end

    @tag :unique
    test "preventing duplicate jobs between processes", %{name: name} do
      parent = self()
      changeset = Worker.new(%{ref: 1}, unique: [period: 60])

      fun = fn ->
        Sandbox.allow(Repo, parent, self())

        {:ok, %Job{id: id}} = Oban.insert(name, changeset)

        id
      end

      ids =
        1..3
        |> Enum.map(fn _ -> Task.async(fun) end)
        |> Enum.map(&Task.await/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      assert 1 == length(ids)
    end

    @tag :unique
    test "scoping uniqueness to specific fields", %{name: name} do
      changeset1 = Job.new(%{}, worker: "A", unique: [fields: [:worker]])
      changeset2 = Job.new(%{}, worker: "B", unique: [fields: [:worker]])

      assert {:ok, job_1} = Oban.insert(name, changeset1)
      assert {:ok, job_2} = Oban.insert(name, changeset2)
      assert {:ok, job_3} = Oban.insert(name, changeset1)

      refute job_1.conflict?
      refute job_2.conflict?
      assert job_3.conflict?
      assert job_1.id == job_3.id
    end

    @tag :unique
    test "scoping uniqueness to specific argument keys", %{name: name} do
      changeset1 = Worker.new(%{id: 1, xd: 1}, unique: [keys: [:id]])
      changeset2 = Worker.new(%{id: 2, xd: 2}, unique: [keys: [:id]])
      changeset3 = Worker.new(%{id: 3, xd: 1}, unique: [keys: [:xd]])
      changeset4 = Worker.new(%{id: 1, xd: 3}, unique: [keys: [:id]])

      assert {:ok, job_1} = Oban.insert(name, changeset1)
      assert {:ok, job_2} = Oban.insert(name, changeset2)
      assert {:ok, job_3} = Oban.insert(name, changeset3)
      assert {:ok, job_4} = Oban.insert(name, changeset4)

      refute job_1.conflict?
      refute job_2.conflict?
      assert job_3.conflict?
      assert job_4.conflict?

      assert job_1.id == job_3.id
      assert job_1.id == job_4.id
    end

    @tag :unique
    test "considering empty args distinct from non-empty args", %{name: name} do
      defmodule MiniUniq do
        use Oban.Worker, unique: [fields: [:args]]

        @impl Worker
        def perform(_job), do: :ok
      end

      changeset1 = MiniUniq.new(%{id: 1})
      changeset2 = MiniUniq.new(%{})

      assert {:ok, %Job{id: id_1}} = Oban.insert(name, changeset1)
      assert {:ok, %Job{id: id_2}} = Oban.insert(name, changeset2)
      assert {:ok, %Job{id: id_3}} = Oban.insert(name, changeset2)

      assert id_1 != id_2
      assert id_2 == id_3
    end

    @tag :unique
    test "scoping uniqueness by specific meta keys", %{name: name} do
      unique = [fields: [:meta], keys: [:slug]]

      changeset1 = Worker.new(%{}, meta: %{slug: "abc123"}, unique: unique)
      changeset2 = Worker.new(%{}, meta: %{slug: "def456"}, unique: unique)

      assert {:ok, %Job{id: id_1}} = Oban.insert(name, changeset1)
      assert {:ok, %Job{id: id_2}} = Oban.insert(name, changeset2)

      assert {:ok, %Job{id: ^id_1}} = Oban.insert(name, changeset1)
      assert {:ok, %Job{id: ^id_2}} = Oban.insert(name, changeset2)
    end

    @tag :unique
    test "scoping uniqueness by state", %{name: name} do
      %Job{id: id_1} = insert!(name, %{id: 1}, state: "available")
      %Job{id: id_2} = insert!(name, %{id: 2}, state: "completed")
      %Job{id: id_3} = insert!(name, %{id: 3}, state: "executing")
      %Job{id: id_4} = insert!(name, %{id: 4}, state: "discarded")

      uniq_insert = fn args, states ->
        Oban.insert(name, Worker.new(args, unique: [states: states]))
      end

      assert {:ok, %{id: ^id_1}} = uniq_insert.(%{id: 1}, [:available])
      assert {:ok, %{id: ^id_2}} = uniq_insert.(%{id: 2}, [:available, :completed])
      assert {:ok, %{id: ^id_2}} = uniq_insert.(%{id: 2}, [:completed, :discarded])
      assert {:ok, %{id: ^id_3}} = uniq_insert.(%{id: 3}, [:completed, :executing])
      assert {:ok, %{id: ^id_4}} = uniq_insert.(%{id: 4}, [:completed, :discarded])
    end

    @tag :unique
    test "scoping uniqueness by period", %{name: name} do
      four_minutes_ago = seconds_ago(240)
      five_minutes_ago = seconds_ago(300)
      nine_minutes_ago = seconds_ago(540)

      uniq_insert = fn args, period ->
        Oban.insert(name, Worker.new(args, unique: [period: period]))
      end

      job_1 = insert!(name, %{id: 1}, inserted_at: four_minutes_ago)
      job_2 = insert!(name, %{id: 2}, inserted_at: five_minutes_ago)
      job_3 = insert!(name, %{id: 3}, inserted_at: nine_minutes_ago)

      assert {:ok, job_4} = uniq_insert.(%{id: 1}, 239)
      assert {:ok, job_5} = uniq_insert.(%{id: 2}, 299)
      assert {:ok, job_6} = uniq_insert.(%{id: 3}, 539)

      assert job_1.id != job_4.id
      assert job_2.id != job_5.id
      assert job_3.id != job_6.id

      assert {:ok, job_7} = uniq_insert.(%{id: 1}, 241)
      assert {:ok, job_8} = uniq_insert.(%{id: 2}, 300)
      assert {:ok, job_9} = uniq_insert.(%{id: 3}, :infinity)

      assert job_7.id in [job_1.id, job_4.id]
      assert job_8.id in [job_2.id, job_5.id]
      assert job_9.id in [job_3.id, job_6.id]
    end

    @tag :unique
    test "scoping uniqueness by period compared to the scheduled time", %{name: name} do
      job_1 = insert!(name, %{id: 1}, scheduled_at: seconds_ago(120))

      uniq_insert = fn args, period, timestamp ->
        Oban.insert(name, Worker.new(args, unique: [period: period, timestamp: timestamp]))
      end

      assert {:ok, job_2} = uniq_insert.(%{id: 1}, 121, :scheduled_at)
      assert {:ok, job_3} = uniq_insert.(%{id: 1}, 119, :scheduled_at)

      assert job_1.id == job_2.id
      assert job_1.id != job_3.id
    end

    @tag :unique
    test "replacing fields on unique conflict", %{name: name} do
      four_seconds = seconds_from_now(4)
      five_seconds = seconds_from_now(5)

      replace = fn opts ->
        opts =
          Keyword.merge(opts,
            replace: [:scheduled_at, :priority],
            unique: [keys: [:id]]
          )

        Oban.insert(name, Worker.new(%{id: 1}, opts))
      end

      assert {:ok, job_1} = replace.(priority: 3, scheduled_at: four_seconds)
      assert {:ok, job_2} = replace.(priority: 2, scheduled_at: five_seconds)

      assert job_1.id == job_2.id
      assert job_1.scheduled_at == four_seconds
      assert job_2.scheduled_at == five_seconds
      assert job_1.priority == 3
      assert job_2.priority == 2
    end

    @tag :unique
    test "replacing fields based on job state", %{name: name} do
      replace = fn args, opts ->
        opts =
          Keyword.merge(opts,
            replace: [scheduled: [:priority]],
            unique: [keys: [:id]]
          )

        Oban.insert(name, Worker.new(args, opts))
      end

      assert {:ok, job_1} = replace.(%{id: 1}, priority: 1, state: "scheduled")
      assert {:ok, job_2} = replace.(%{id: 2}, priority: 1, state: "executing")
      assert {:ok, job_3} = replace.(%{id: 1}, priority: 2)
      assert {:ok, job_4} = replace.(%{id: 2}, priority: 2)

      assert job_1.id == job_3.id
      assert job_2.id == job_4.id
      assert job_3.priority == 2
      assert job_4.priority == 1
    end
  end

  defp start_supervised_oban(context) do
    name =
      context
      |> Map.get(:oban_opts, [])
      |> Keyword.put_new(:engine, @engine)
      |> Keyword.put_new(:repo, @repo)
      |> Keyword.put_new(:testing, :manual)
      |> start_supervised_oban!()

    {:ok, name: name}
  end
end
