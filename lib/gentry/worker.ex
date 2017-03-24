defmodule Gentry.Worker do
  @moduledoc """
  The worker is responsible for coordinating the retries of the task given in
  the form of a function called `task_function`.
  
  The task is spawened and monitored by the worker using `spawn_monitor`.

  The number of retries and the backoff between retries are taken from
  the configuration.
  """

  use GenServer

  require Logger

  defmodule State do
    @moduledoc """
    - `retries_remaining` is counting down to 0 for retries
    - `task_function` is the whole purpose: the task we're trying to run
    - `runner_pid` is the
    process that requested the task to be run and will get the reply
    - `spawned_pid` is the spawned task that's executing `task_function`
    """
    defstruct retries_remaining: nil, task_function: nil, runner_pid: nil, spawned_pid: nil
  end

  def start_link(task_function, runner_pid, ops \\ []) do
    GenServer.start_link(__MODULE__, [task_function, runner_pid], ops)
  end

  def init([task_function, runner_pid]) do
    send(self(), :execute_function)
    initial_state = %State{retries_remaining: retries(), task_function: task_function, runner_pid: runner_pid}
    Logger.debug "Worker #{inspect self()} is starting with inital state: #{inspect initial_state}"
    {:ok, initial_state}
  end

  def handle_info(:execute_function, state) do
    spawn_task(state)
  end
  def handle_info({:DOWN, _ref, :process, pid, :normal}, state) do
    Logger.debug "Normal shutdown of #{inspect pid}"
    send(state.runner_pid, {:gentry, self(), :ok, :normal})
    {:stop, :normal, state}
  end
  def handle_info({:DOWN, _ref, :process, pid, error}, state) do
    Logger.debug "Abnormal shutdown of #{inspect pid}, error: #{inspect error}, retries remaining: #{state.retries_remaining}"
    handle_failure(state, error)
  end
  def handle_info(msg, state) do
    # catch all
    Logger.debug "Unexpected message: #{inspect msg}"
    {:noreply, state}
  end

  defp spawn_task(state) do
    {pid, _ref} = spawn_monitor(state.task_function)
    {:noreply, %State{state | spawned_pid: pid}}
  end

  defp handle_failure(state, error) do
    if state.retries_remaining > 0 do
      send(state.runner_pid, {:gentry, self(), :retry, state.retries_remaining})
      Logger.debug "Retrying with #{state.retries_remaining} retries remaining"
      retry()
      {
        :noreply,
        %State{state | retries_remaining: (state.retries_remaining - 1)},
        :infinity
      }
    else
      send(state.runner_pid, {:gentry, self(), :error, error})
      {:stop, {:shutdown, :max_retries_exceeded}, state}
    end
  end

  defp retry do
    Process.send_after(self(), :execute_function, retry_backoff())
  end
  
  defp retries do
    Application.get_env(:gentry, :retries, 5)
  end
  
  defp retry_backoff do
    Application.get_env(:gentry, :retry_backoff, 5)
  end
end
