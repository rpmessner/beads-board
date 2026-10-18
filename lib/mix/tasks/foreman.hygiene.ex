defmodule Mix.Tasks.Foreman.Hygiene do
  use Mix.Task
  @shortdoc "Reject license material and operator paths in the repository tree"
  @moduledoc """
  Scans tracked and nonignored untracked files, not just the staged diff. Never
  prints matching text or file names. Also checks exact license environment
  values when available; does not read Hex credentials or any secret file.
  """

  @impl true
  def run([]) do
    Mix.Task.run("compile")

    {listing, 0} =
      System.cmd("git", ["ls-files", "-z", "--cached", "--others", "--exclude-standard"])

    secrets = Enum.map(~w(FLUXON_LICENSE_KEY FLUXON_KEY_FINGERPRINT), &System.get_env/1)

    findings =
      listing
      |> String.split(<<0>>, trim: true)
      |> Enum.uniq()
      |> Enum.flat_map(fn path ->
        case File.lstat(path) do
          {:error, :enoent} ->
            []

          {:ok, %{type: :regular}} ->
            case File.read(path) do
              {:ok, content} -> Foreman.Hygiene.violations(content, secrets)
              {:error, _} -> [:unreadable_file]
            end

          {:ok, %{type: :symlink}} ->
            # Do not follow a link out of the repository, including to a secret.
            case File.read_link(path) do
              {:ok, target} -> Foreman.Hygiene.violations(target, secrets)
              {:error, _} -> [:unreadable_file]
            end

          _ ->
            [:unsupported_file]
        end
      end)
      |> Enum.frequencies()

    if findings != %{}, do: Mix.raise("Repository hygiene failed: #{inspect(findings)}")
    Mix.shell().info("Repository hygiene: no license material or operator paths detected")
  end
end
