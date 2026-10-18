defmodule Foreman.AdoptEscriptTest do
  use ExUnit.Case, async: false

  test "actual escript adopts offline and hook rejects invalid tickets" do
    {_, 0} = System.cmd("mix", ["escript.build"], stderr_to_stdout: true)
    executable = Path.expand("foreman")
    base = Path.join(System.tmp_dir!(), "fm-adopt-cli-#{System.unique_integer([:positive])}")
    root = Path.join(base, "demo")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(base) end)
    {_, 0} = System.cmd("git", ["init", "-q", root])

    File.write!(
      Path.join(root, ".git/hooks/pre-commit"),
      "#!/usr/bin/env python3\nprint('custom hook survived')\n"
    )

    File.chmod!(Path.join(root, ".git/hooks/pre-commit"), 0o755)

    env = [
      {"FOREMAN_CONFIG_DIR", Path.join(base, "config")},
      {"FOREMAN_URL", "http://127.0.0.1:1"},
      {"PATH", Path.dirname(executable) <> ":" <> System.get_env("PATH")}
    ]

    {text, 0} = System.cmd(executable, ["adopt", "--json"], cd: root, env: env)
    result = Jason.decode!(text)
    assert result["entry"]["tickets"] == "files"
    assert result["diff"] =~ "BEGIN FOREMAN"
    {text, 0} = System.cmd(executable, ["adopt", root, "--json"], env: env)
    assert Jason.decode!(text)["changes"] == []
    hook = Path.join(root, ".foreman/hooks/pre-commit")
    {output, 0} = System.cmd(hook, [], cd: root, env: env, stderr_to_stdout: true)
    assert output =~ "custom hook survived"
    File.rm!(hook)
    {_, 0} = System.cmd(executable, ["adopt", root, "--json"], env: env)
    {repaired, 0} = System.cmd(hook, [], cd: root, env: env, stderr_to_stdout: true)
    assert repaired =~ "custom hook survived"
    File.write!(Path.join(root, "tickets/demo-bad.md"), "broken")
    {text, code} = System.cmd(hook, [], cd: root, env: env)
    assert code != 0
    assert text =~ "demo-bad.md"
    {_, 2} = System.cmd(executable, ["adopt", root, "--bogus"], env: env, stderr_to_stdout: true)
  end
end
