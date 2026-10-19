defmodule Foreman.DevserveTest do
  use ExUnit.Case, async: false
  alias Foreman.Previews.Devserve

  setup do
    dir = Path.join(System.tmp_dir!(), "fm-devserve-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "apps.toml"), "apps = []\n")
    script = Path.join(dir, "devserve")

    File.write!(script, """
    #!/usr/bin/env python3
    import json, os, sys
    with open(os.path.join(os.environ['DEVSERVE_CONFIG_DIR'], 'argv.json'), 'w') as f:
        json.dump({'args': sys.argv[1:], 'owner': os.environ.get('FOREMAN_SESSION')}, f)
    if sys.argv[1] == 'ls':
        print(json.dumps({'previews': [], 'main_units': [{'unit':'foreman-web.service'}]}))
    if sys.argv[1] == 'logs':
        print('x' * 20000)
    """)

    File.chmod!(script, 0o755)
    old = Map.take(System.get_env(), ["PATH", "DEVSERVE_CONFIG_DIR"])
    System.put_env("PATH", dir <> ":" <> System.fetch_env!("PATH"))
    System.put_env("DEVSERVE_CONFIG_DIR", dir)

    on_exit(fn ->
      for key <- ["PATH", "DEVSERVE_CONFIG_DIR"] do
        if old[key], do: System.put_env(key, old[key]), else: System.delete_env(key)
      end

      File.rm_rf!(dir)
    end)

    {:ok, dir: dir}
  end

  test "adapter excludes main services and passes metacharacters as one worktree argv", %{
    dir: dir
  } do
    assert {:ok, []} = Devserve.list()
    path = Path.join(dir, "a space;$(touch injected)")
    assert :ok = Devserve.up(path, "ticket owner")
    assert %{"args" => ["up", ^path], "owner" => "ticket owner"} = read_args(dir)
    refute File.exists?(Path.join(dir, "injected"))
    assert :ok = Devserve.down("devserve-test.service")
    assert %{"args" => ["down", "devserve-test.service", "--drop-db"]} = read_args(dir)
    assert {:error, "Invalid preview unit"} = Devserve.down("foreman-web.service")
    assert {:error, "Invalid preview unit"} = Devserve.down("--help")
    assert {:error, "Invalid worktree"} = Devserve.up("--help", "owner")
  end

  test "logs are bounded", %{dir: _dir} do
    assert {:ok, logs} = Devserve.logs("devserve-test.service")
    assert byte_size(logs) == 16_384
  end

  defp read_args(dir), do: dir |> Path.join("argv.json") |> File.read!() |> Jason.decode!()
end
