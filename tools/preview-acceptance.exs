# mix run --no-start tools/preview-acceptance.exs
# Real endpoint and Oban, with discovery disabled to preserve the copied fixture.
# Trace external boundaries without replacing their implementations or logging arguments.
unless System.get_env("PREVIEW") == "1", do: raise("requires PREVIEW=1")
Application.put_env(:foreman, :runtime_enabled, false)

Application.put_env(
  :foreman,
  ForemanWeb.Endpoint,
  Keyword.put(Application.fetch_env!(:foreman, ForemanWeb.Endpoint), :server, true)
)

for module <- [System, Foreman.Forge.GitHub], do: Code.ensure_loaded!(module)

trace_file = System.fetch_env!("PREVIEW_TRACE_FILE")
File.write!(trace_file, "")

tracer =
  spawn(fn ->
    loop = fn loop ->
      receive do
        {:trace, _, :call, {System, :cmd, [executable | _]}} ->
          if Path.basename(executable) in ["git", "gh", "tmux"],
            do: File.write!(trace_file, "command: #{Path.basename(executable)}\n", [:append])

          loop.(loop)

        {:trace, _, :call, {Foreman.Forge.GitHub, function, _}} ->
          File.write!(trace_file, "forge: #{function}\n", [:append])
          loop.(loop)

        _ ->
          loop.(loop)
      end
    end

    loop.(loop)
  end)

:erlang.trace(:all, true, [:call, {:tracer, tracer}])
:erlang.trace_pattern({System, :cmd, 3}, true, [])

for function <- [:list, :merge, :retarget],
    do: :erlang.trace_pattern({Foreman.Forge.GitHub, function, :_}, true, [])

{:ok, _} = Application.ensure_all_started(:foreman)
Process.sleep(:infinity)
