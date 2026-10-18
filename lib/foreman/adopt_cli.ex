defmodule Foreman.AdoptCLI do
  @moduledoc false
  def run(args, opts \\ []) do
    {flags, paths, invalid} = OptionParser.parse(args, strict: [json: :boolean])

    if invalid != [] or length(paths) > 1 do
      IO.puts(:stderr, "usage: foreman adopt [path] [--json]")
      2
    else
      root = Path.expand(List.first(paths) || Keyword.get(opts, :cwd, File.cwd!()))

      case Foreman.Adopt.run(root, opts) do
        {:ok, result} ->
          diff = diff(root)

          if flags[:json] do
            IO.puts(Jason.encode!(Map.put(result, :diff, diff)))
          else
            IO.puts(result.config_entry)
            IO.puts("Repository: #{Jason.encode!(result.entry)}")

            if result.comparison do
              IO.puts("Comparison equal: #{inspect(result.comparison)}")
              IO.puts("Export: #{result.export}")
            end

            IO.puts(Enum.join(result.changes, "\n"))
            IO.puts(diff)
            IO.puts("Not committed. Review the full change before committing.")
          end

          0

        {:error, reason} ->
          IO.puts(:stderr, "adopt refused: #{inspect(reason)}")
          2
      end
    end
  rescue
    e ->
      IO.puts(:stderr, "adopt failed: #{Exception.message(e)}")
      2
  end

  defp diff(root) do
    {_, head_code} =
      System.cmd("git", ["-C", root, "rev-parse", "--verify", "HEAD"], stderr_to_stdout: true)

    args = if head_code == 0, do: ["HEAD"], else: []

    {tracked, 0} =
      System.cmd("git", ["-C", root, "diff", "--no-ext-diff"] ++ args, stderr_to_stdout: true)

    {names, 0} =
      System.cmd("git", ["-C", root, "ls-files", "--others", "--exclude-standard", "-z"])

    additions =
      names
      |> String.split(<<0>>, trim: true)
      |> Enum.map_join("\n", fn name ->
        {text, _} =
          System.cmd(
            "git",
            ["diff", "--no-ext-diff", "--no-index", "/dev/null", Path.join(root, name)],
            stderr_to_stdout: true
          )

        text
      end)

    tracked <> additions
  end
end
