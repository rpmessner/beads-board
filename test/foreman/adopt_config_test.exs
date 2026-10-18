defmodule Foreman.AdoptConfigTest do
  use ExUnit.Case, async: true

  test "appends once without rewriting bytes and refuses key or path collisions" do
    dir = Path.join(System.tmp_dir!(), "fm-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    path = Path.join(dir, "foreman.toml")

    original =
      "# keep this comment\n[[repos]]\nkey = \"old\"\npath = \"/tmp/old\"\nprefix = \"old\"\n"

    File.write!(path, original)

    entry = %{
      "key" => "demo",
      "path" => "/tmp/demo",
      "prefix" => "demo",
      "tickets" => "files",
      "github" => "owner/demo"
    }

    assert {:ok, text} = Foreman.AdoptConfig.append(dir, entry)
    assert File.read!(path) == original <> text
    assert text =~ "[[repos]]"
    assert {:ok, ""} = Foreman.AdoptConfig.append(dir, entry)
    assert {:error, _} = Foreman.AdoptConfig.append(dir, %{entry | "path" => "/tmp/other"})
    assert {:error, _} = Foreman.AdoptConfig.append(dir, %{entry | "key" => "other"})
    assert File.read!(path) == original <> text
  end
end
