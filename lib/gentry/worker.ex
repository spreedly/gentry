defmodule Gentry.Worker do
  @moduledoc """
  The worker is responsible for actually running and coordinating the
  retries of the task given in the form of a function called
  `task_function`.
  
  The task is spawened and monitored by the worker using
  `Task.Supervisor.async_nolink`

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
    - `task` is the spawned task that's executing `task_function`
    """
    defstruct retries_remaining: nil,
        task_function: nil, runner_pid: nil,
        task: nil
  end

  def start_link(task_function, runner_pid, ops \\ []) do
    GenServer.start_link(__MODULE__, [task_function, runner_pid], ops)
  end

  def init([task_function, runner_pid]) do
    initial_state = %State{retries_remaining: retries(),
                          task_function: task_function,
                          runner_pid: runner_pid}
    Logger.debug "Worker #{inspect self()} is starting with inital state: #{inspect initial_state}"
    send(self(), {:execute_function})
    {:ok, initial_state}
  end

  ## Internal

  def handle_info({:execute_function}, state) do
    spawn_task(state)
  end
  # Receive the result of the task
  def handle_info({ref, result}, %{task: %{ref: task_ref}} = state)
      when ref == task_ref do
    Logger.debug "Received completion from task: #{inspect result}"
    # Send the reply
    send(state.runner_pid, {:gentry, self(), :ok, result})
    {:noreply, state}
  end
  # Shutdown of spawned task
  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{task: %{ref: task_ref}} = state)
      when ref == task_ref do
    Logger.debug "Normal shutdown of #{inspect ref}"
    {:stop, :normal, state}
  end
  def handle_info({:DOWN, ref, :process, _pid, error}, %{task: %{ref: task_ref}} = state)
      when ref == task_ref do
    Logger.warn "Abnormal shutdown of #{inspect ref}, error: #{inspect error}, retries remaining: #{state.retries_remaining}"
    handle_failure(state, error)
  end
  def handle_info(msg, state) do
    # catch all
    Logger.warn "Unexpected message: #{inspect msg} with state: #{inspect state}"
    {:noreply, state}
  end

  def compute_delay(retries_remaining) do
    retry_backoff() * :math.pow(2, retries() - retries_remaining)
    |> round
  end

  defp spawn_task(state) do
    task = Task.Supervisor.async_nolink(:task_supervisor, state.task_function)
    new_state = state
      |> Map.put(:task, task)
    {:noreply, new_state}
  end

  defp handle_failure(state, error) do
    if state.retries_remaining > 0 do
      send(state.runner_pid, {:gentry, self(), :retry, state.retries_remaining})
      Logger.debug "Retrying with #{state.retries_remaining} retries remaining"
      retry(state.retries_remaining)
      
      {:noreply,
       %State{state | retries_remaining: (state.retries_remaining - 1)},
       :infinity}
    else
      send(state.runner_pid, {:gentry, self(), :error, error})
      {:stop, {:shutdown, :max_retries_exceeded}, state}
    end
  end

  defp retry(retries_remaining) do
    Process.send_after(self(), {:execute_function}, compute_delay(retries_remaining))
  end
  
  defp retries do
    Application.get_env(:gentry, :retries, 5)
  end
  
  defp retry_backoff do
    Application.get_env(:gentry, :retry_backoff, 5_000)
  end
end
