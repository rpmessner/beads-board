defmodule Board.RuntimeConfigTest do
  use ExUnit.Case, async: false

  setup do
    keys = ["BOARD_ROLE", "DATABASE_URL", "SECRET_KEY_BASE"]
    previous = Map.new(keys, &{&1, System.get_env(&1)})
    Enum.each(keys, &System.delete_env/1)
    System.put_env("DATABASE_URL", "ecto://localhost/beads_board_test")

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)
  end

  test "worker production config does not require an endpoint signing secret" do
    System.put_env("BOARD_ROLE", "worker")
    config = Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    assert config[:board][:role] == "worker"
    assert config[:board][BoardWeb.Endpoint][:http][:ip] == {127, 0, 0, 1}
  end

  test "web still requires the endpoint secret in production" do
    System.put_env("BOARD_ROLE", "web")

    assert_raise RuntimeError, ~r/SECRET_KEY_BASE is missing/, fn ->
      Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    end
  end

  test "all is the default and unknown role names are rejected" do
    config = Config.Reader.read!("config/runtime.exs", env: :test, target: :host)
    assert config[:board][:role] == "all"
    System.put_env("BOARD_ROLE", "typo")

    assert_raise RuntimeError, "BOARD_ROLE must be web, worker or all", fn ->
      Config.Reader.read!("config/runtime.exs", env: :test, target: :host)
    end
  end
end
