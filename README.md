# Gentry

**Because failures are a royal pain.**

Use Gentry to run tasks with a configurable retry and backoff period.

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
      retry_delay: 5_000
    ```

## Usage

### `Gentry`

Use the `Gentry` module for easy, synchronous calls with retries.

```elixir
case Gentry.run_task(fn -> write_to_database(changeset) end) do
  {:ok, :normal} ->
    Logger.debug "Successfully processed changeset: #{inspect changeset}"
    count(%{"partition" => message.partition}, @stat_count_processed)
  {:error, error} ->
    Logger.debug "Failed to process changeset: #{inspect changeset}, because: #{inspect error}"
end
```

### Asynchronous Operation

From within a `GenServer`, start a new task by running:

```elixir
{:ok, pid} = Gentry.Supervisor.start_worker(f, self())
```

Then handle the result:

```elixir
def handle_info({:gentry, pid, :ok, :normal}, state) do
  Logger.debug "Received success from child: #{inspect pid}"
  state
end
def handle_info({:gentry, pid, :error, error}, state) do
  Logger.debug "Received error from child: #{inspect pid}"
end
def handle_info({:gentry, ^pid, :retry, remaining}, state) do
  Logger.debug "Received retry from child: #{inspect pid}, #{remaining} tries remaining"
  state
end
```
