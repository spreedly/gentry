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
          send(self(), {:stop})
          {:reply, :task_ok, failures}
        _ ->
          Logger.debug "Failures to go: #{failures}"
          {:reply, :task_error, %{state | failures: (failures - 1)}}
      end
    end
    def handle_call({:stop}, _from, state) do
      Logger.debug "Stopping"
      {:stop, :normal, state}
    end
    def handle_call(something, _from, state) do
      Logger.debug "Handling call with #{inspect something}"
      {:noreply, state}
    end
  end

  setup do
    {:ok, pid} = Gentry.Supervisor.start_link()
    %{supervisor_pid: pid}
  end

  test "run task" do
    me = self()

    {:ok, pid} = Server.start_link(0, me)
    assert {:ok, :task_ok} == Gentry.run_task(fn ->
      :task_ok = Server.run(pid)
    end)

    assert_received {:message, ^me}
  end

  test "run task with single failure" do
    me = self()

    {:ok, pid} = Server.start_link(1, me)
    assert {:ok, :task_ok} == Gentry.run_task(fn ->
      :task_ok = Server.run(pid)
    end)

    assert_received {:message, ^me}
  end

  test "run task with five failures" do
    me = self()

    {:ok, pid} = Server.start_link(5, me)
    assert {:ok, :task_ok} == Gentry.run_task(fn ->
      :task_ok = Server.run(pid)
    end)

    assert_received {:message, ^me}
  end

  test "run task with six failures" do
    me = self()

    {:ok, pid} = Server.start_link(6, me)
    {:error, _task_error} = Gentry.run_task(fn ->
      :ok = Server.run(pid)
    end)

    refute_received {:message, ^me}
  end

end
