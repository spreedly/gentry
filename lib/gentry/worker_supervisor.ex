defmodule Gentry.WorkerSupervisor do
  @moduledoc """
  Support running a transient child/worker process.

  A more convenient interface is with `Gentry.Supervisor` and `Gentry`.

  Use this if an async interface is needed. Use the `Gentry` module as
  a guide to what messages to expect.
  """
  
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  A function is expected for `task_function`. The value of `runner_pid`
  is usually `self()` and will receive the messages sent as a result of
  working on `task_function`.

  - `{:ok, result}` - The task ran successfully and returned `result`
  - `{:error, error}` - The task failed with reason, `error`
  """
  def start_worker(task_function, runner_pid) do
    Supervisor.start_child(__MODULE__, [task_function, runner_pid])
  end

  def init(:ok) do
    children = [
      worker(Gentry.Worker, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
