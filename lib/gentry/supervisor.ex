defmodule Gentry.Supervisor do
  @moduledoc """
  Support running a transient child/worker process.

  Hook this up as a supervisor in Application or whereever appropriate for your
  app.

  Use `start_worker/2` to start a new worker. The sending process will be sent a
  message with the result. The message format is:

  - `{:ok, :normal}` - The task ran successfully
  - `{:error, error}` - The task failed with reason, `error`

  Use `Gentry.TaskRunner` for a convenient synchronous interface.
  """
  
  use Supervisor

  def start_link(ops \\ [name: __MODULE__]) do
    Supervisor.start_link(__MODULE__, :ok, ops)
  end

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