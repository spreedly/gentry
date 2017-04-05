defmodule Gentry.Test.GentryTest do
  use ExUnit.Case
  doctest Gentry

  require Logger

  defmodule Server do
    use GenServer
    def start_link(failures, parent_pid) do
      GenServer.start_link(__MODULE__, [failures, parent_pid])
    end
    def init([failures, parent_pid]) do
      {:ok, %{failures: failures, parent_pid: parent_pid}}
    end
    def run do
      GenServer.call(__MODULE__, :run)
    end
    def run(pid) do
      GenServer.call(pid, :run)
    end
    def handle_call(:run, _from, %{failures: failures, parent_pid: parent_pid} = state) do
      Logger.debug "Handling call with #{failures}"
      case failures do
        0 ->
          Logger.debug "Finished"
          send(parent_pid, {:message, parent_pid})
          {:reply, :ok, failures}
        _ ->
          Logger.debug "Failures to go: #{failures}"
          {:reply, :error, %{state | failures: (failures - 1)}}
      end
    end
  end

  setup do
    {:ok, pid} = Gentry.Supervisor.start_link()
    %{supervisor_pid: pid}
  end

  test "run task" do
    me = self()

    {:ok, pid} = Server.start_link(0, me)
    assert {:ok, :normal} == Gentry.run_task(fn ->
      :ok = Server.run(pid)
    end)

    assert_received {:message, ^me}
  end

  test "run task with single failure" do
    me = self()

    {:ok, pid} = Server.start_link(1, me)
    assert {:ok, :normal} == Gentry.run_task(fn ->
      :ok = Server.run(pid)
    end)

    assert_received {:message, ^me}
  end

  test "run task with five failures" do
    me = self()

    {:ok, pid} = Server.start_link(5, me)
    assert {:ok, :normal} == Gentry.run_task(fn ->
      :ok = Server.run(pid)
    end)

    assert_received {:message, ^me}
  end

  test "run task with six failures" do
    me = self()

    {:ok, pid} = Server.start_link(6, me)
    {:error, _error} = Gentry.run_task(fn ->
      :ok = Server.run(pid)
    end)

    refute_received {:message, ^me}
  end
end
