defmodule Gentry.Supervisor do
  @moduledoc """
  Setup Gentry for running workers and tasks.

  Hook this up as a supervisor in Application or whereever appropriate for your
  app.

  Use `Gentry.TaskRunner` for a convenient synchronous interface.
  """
  
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      supervisor(Gentry.WorkerSupervisor, []),
      supervisor(Task.Supervisor, [[name: :task_supervisor]])
    ]
    supervise(children, strategy: :one_for_one)
  end
end