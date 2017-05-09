defmodule Gentry.Test.WorkerTest do
  use ExUnit.Case
  doctest Gentry.Worker

  alias Gentry.Worker

  test "compute retry delay" do
    Application.put_env(:gentry, :retry_backoff, 5_000)

    assert 5_000 == Worker.compute_delay(5)
    assert 10_000 == Worker.compute_delay(4)
    assert 20_000 == Worker.compute_delay(3)
    assert 40_000 == Worker.compute_delay(2)
    assert 80_000 == Worker.compute_delay(1)
    assert 160_000 == Worker.compute_delay(0)
  end

end
