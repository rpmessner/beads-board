defmodule Board.HygieneTest do
  use ExUnit.Case, async: true

  test "blocks operator paths without returning the matched material" do
    for path <- [
          "/ho" <> "me/operator/dev",
          "/Us" <> "ers/operator/dev",
          "C:" <> "\\Users\\operator",
          "/mnt/c/Us" <> "ers/operator"
        ] do
      assert :operator_path in Board.Hygiene.violations(path)
    end

    assert Board.Hygiene.violations("~/dev/sample") == []
  end

  test "blocks environment values and literal license assignments" do
    secret = "fixture-" <> String.duplicate("x", 32)
    assert :license_material in Board.Hygiene.violations("prefix #{secret} suffix", [secret])

    for key <- ["FLUXON_LICENSE_KEY", "FLUXON_KEY_FINGERPRINT"] do
      assert :license_material in Board.Hygiene.violations(key <> "=\"" <> secret <> "\"")
    end

    assert Board.Hygiene.violations("$FLUXON_LICENSE_KEY", [nil, ""]) == []
    assert Board.Hygiene.violations("System.get_env(\"FLUXON_LICENSE_KEY\")") == []
  end
end
