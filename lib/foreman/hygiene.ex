defmodule Foreman.Hygiene do
  @moduledoc "Content-only repository hygiene checks; findings never contain matched material."

  @operator_path ~r{(?:/(?:home|Users)/[A-Za-z0-9_.-]+|[A-Za-z]:\\Users\\[A-Za-z0-9_.-]+|/mnt/[a-z]/Users/[A-Za-z0-9_.-]+)}
  @license_assignment ~r/FLUXON_(?:LICENSE_KEY|KEY_FINGERPRINT)["']?\s*(?:=|:)\s*["']?[A-Za-z0-9][A-Za-z0-9._+\/=:-]{7,}/i

  def violations(text, secrets \\ []) do
    []
    |> finding(Regex.match?(@operator_path, text), :operator_path)
    |> finding(license?(text, secrets), :license_material)
  end

  defp license?(text, secrets) do
    Regex.match?(@license_assignment, text) or
      Enum.any?(secrets, fn value ->
        is_binary(value) and byte_size(value) >= 8 and String.contains?(text, value)
      end)
  end

  defp finding(findings, true, category), do: findings ++ [category]
  defp finding(findings, false, _category), do: findings
end
