defmodule Foreman.RuntimeConfigTest do
  use ExUnit.Case, async: false

  setup do
    keys = [
      "FOREMAN_ROLE",
      "FOREMAN_CONFIG_DIR",
      "FOREMAN_DISCOVERY_ROOT",
      "DATABASE_URL",
      "SECRET_KEY_BASE",
      "PORT",
      "PHX_SERVER"
    ]

    previous = Map.new(keys, &{&1, System.get_env(&1)})
    Enum.each(keys, &System.delete_env/1)
    System.put_env("DATABASE_URL", "ecto://localhost/foreman_test")

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)
  end

  test "dev honors the preview port and database URL" do
    System.put_env("PORT", "4891")
    System.put_env("DATABASE_URL", "ecto://localhost/foreman_preview_scratch")
    config = Config.Reader.read!("config/runtime.exs", env: :dev, target: :host)
    assert config[:foreman][ForemanWeb.Endpoint][:http][:port] == 4891
    assert config[:foreman][Foreman.Repo][:url] == "ecto://localhost/foreman_preview_scratch"
  end

  test "worker production config does not require an endpoint signing secret" do
    System.put_env("FOREMAN_ROLE", "worker")
    config = Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    assert config[:foreman][:role] == "worker"
    assert config[:foreman][ForemanWeb.Endpoint][:http][:ip] == {127, 0, 0, 1}
    assert config[:foreman][:config_directory] == Path.expand("~/.config/foreman")
    assert config[:foreman][:discovery_root] == Path.expand("~/dev")

    System.put_env("FOREMAN_CONFIG_DIR", "/tmp/foreman-config-test")
    System.put_env("FOREMAN_DISCOVERY_ROOT", "/tmp/foreman-discovery-test")
    overridden = Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    assert overridden[:foreman][:config_directory] == "/tmp/foreman-config-test"
    assert overridden[:foreman][:discovery_root] == "/tmp/foreman-discovery-test"
  end

  test "web still requires the endpoint secret in production" do
    System.put_env("FOREMAN_ROLE", "web")

    assert_raise RuntimeError, ~r/SECRET_KEY_BASE is missing/, fn ->
      Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    end
  end

  test "web uses its production secret and serves only the configured loopback port" do
    System.put_env("FOREMAN_ROLE", "web")
    System.put_env("SECRET_KEY_BASE", String.duplicate("test-only", 8))
    System.put_env("PORT", "4871")
    System.put_env("PHX_SERVER", "true")
    config = Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    endpoint = config[:foreman][ForemanWeb.Endpoint]
    assert endpoint[:secret_key_base] == String.duplicate("test-only", 8)
    assert endpoint[:server]
    assert endpoint[:http][:ip] == {127, 0, 0, 1}
    assert endpoint[:http][:port] == 4871
  end

  test "all requires the endpoint secret in production" do
    assert_raise RuntimeError, ~r/SECRET_KEY_BASE is missing/, fn ->
      Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    end
  end

  test "worker still requires the production database" do
    System.put_env("FOREMAN_ROLE", "worker")
    System.delete_env("DATABASE_URL")

    assert_raise RuntimeError, ~r/DATABASE_URL is missing/, fn ->
      Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    end
  end

  test "all is the default and unknown role names are rejected" do
    config = Config.Reader.read!("config/runtime.exs", env: :test, target: :host)
    assert config[:foreman][:role] == "all"
    System.put_env("FOREMAN_ROLE", "typo")

    assert_raise RuntimeError, "FOREMAN_ROLE must be web, worker or all", fn ->
      Config.Reader.read!("config/runtime.exs", env: :test, target: :host)
    end
  end
end
