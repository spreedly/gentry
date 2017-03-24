defmodule Gentry do
  @moduledoc """
  This is a convenience module for running synchronous tasks.

  Each "task" is run in a separate spawned process.
  """

  require Logger

  @doc """
  Run the task (function) in an isolated process. The return values are:
  `{:ok, :normal}` - The task ran successfully
  `{:error, error}` - The task failed with reason, `error`

  The task will be retried and respond if successful or if the number of
  retries has been exhausted.
  """
  def run_task(task_function) do
    {:ok, pid} = Gentry.Supervisor.start_worker(task_function, self())
    Logger.debug "#{inspect self()} - Started child with pid: #{inspect pid}"
    receive_result(pid)
  end

  defp receive_result(pid) do
    Logger.debug "#{inspect self()} - Waiting on a reply from #{inspect pid}"
    receive do
      {:gentry, ^pid, :ok, :normal} = res ->
        Logger.debug "#{inspect self()} - Received success from child: #{inspect res}"
        {:ok, :normal}
      {:gentry, ^pid, :error, error} = res ->
        Logger.debug "#{inspect self()} - Received error from child: #{inspect res}"
        {:error, error}
      {:gentry, ^pid, :retry, _remaining} = res ->
        Logger.debug "#{inspect self()} - Received retry from child: #{inspect res}"
        receive_result(pid)
    end
  end
end
