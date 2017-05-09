# Gentry

**Because failures are a royal pain.**

Use Gentry to run tasks with a configurable retry and backoff period.

Gentry will try each task, given as a funcion. If it fails, Gentry will
retry the task `retries` number of times. The defalt value for `retries`
is `5`.

Before running the task after it fails, Gentry will use the configured
`retry_backoff` value as milliseconds. The default value for
`retry_backoff` is `5000`.

The computed backoff for each retry is exponentially doubled:

```elixir
# something like this ...
retry_backoff() * :math.pow(2, retries() - retries_remaining())
```

So the time between the first _try_ and the first _retry_ is:

```
   5000 * :math.pow(2, 5 - 5)
=> 5000 * :math.pow(2, 0)
=> 5000 * 1
=> 5000
```

The time between the first retry and the second retry is twice the
`retry_backoff` time, etc.

## Installation

1. Add `gentry` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:gentry, git: "https://github.com/spreedly/gentry.git", branch: "master"}]
    end
    ```

2. If you're using Elixir 1.3, ensure `gentry` is started with your application:

    ```elixir
    def application do
      [applications: [:logger, :gentry]]
    end
    ```

3. Configure the Gentry supervisor:

    ```elixir
    # ...
    children = [
      # ...
      supervisor(Gentry.Supervisor, []),
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
    ```

    ```elixir
    # config.exs
    config :gentry,
      retries: 5,
      retry_backoff: 5_000 # milliseconds
    ```

## Usage

### `Gentry`

Use the `Gentry` module for easy, synchronous calls with retries.

```elixir
case Gentry.run_task(fn -> write_to_database(changeset) end) do
  {:ok, _result} ->
    Logger.debug "Successfully processed changeset: #{inspect changeset}"
    count(%{"partition" => message.partition}, @stat_count_processed)
  {:error, error} ->
    Logger.debug "Failed to process changeset: #{inspect changeset}, because: #{inspect error}"
end
```

### Asynchronous Operation

From within a `GenServer`, start a new task by running:

```elixir
{:ok, pid} = Gentry.WorkerSupervisor.start_worker(f, self())
```

Then handle the result:

```elixir
def handle_info({:gentry, pid, :ok, result}, state) do
  Logger.debug "Received success from child: #{inspect pid} with result: #{inspect result}"
  state
end
def handle_info({:gentry, pid, :error, error}, state) do
  Logger.debug "Received error from child: #{inspect pid}"
end
def handle_info({:gentry, pid, :retry, remaining}, state) do
  Logger.debug "Received retry notification from child: #{inspect pid}, #{remaining} tries remaining"
  state
end
```

### Failures

For Gentry, a failure is either:

* A task that has exited abormally (see the description [here](https://hexdocs.pm/elixir/Task.Supervisor.html#async_nolink/2))
* A task that returns a value not matching either `:ok` or `{:ok, _}`

## Limitations

### Backoff

Gentry only supports exponential doubling for its backoff algorithm.

### Naming

Gentry uses a fixed naming scheme, so multiple instances of the Gentry
supervisors is not possible.
