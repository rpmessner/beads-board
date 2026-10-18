defmodule Mix.Tasks.Board.Fsm.Docs do
  use Mix.Task
  @shortdoc "Generate diagrams and matrices for compiled Board.Fsm machines"
  @moduledoc """
  Run `MIX_ENV=test mix board.fsm.docs` to include the stage/epic fixtures.
  Without arguments, discovers machines in this application's compiled modules.
  Optional arguments select fully qualified module names from that list (no atom
  creation). Writes docs/machines/<last_module_segment_in_snake_case>.md.
  Does not start the application or access a database.
  """

  @impl true
  def run(args) do
    Mix.Task.run("compile")
    {:ok, modules} = :application.get_key(:board, :modules)

    machines =
      modules
      |> Enum.filter(fn module ->
        Code.ensure_loaded?(module) and function_exported?(module, :__fsm__, 1)
      end)
      |> Enum.sort()

    selected =
      if args == [],
        do: machines,
        else:
          Enum.map(args, fn name ->
            Enum.find(machines, &(inspect(&1) == name)) || Mix.raise("Unknown machine: #{name}")
          end)

    named = Enum.map(selected, &{&1, &1 |> Module.split() |> List.last() |> Macro.underscore()})

    if length(Enum.uniq_by(named, &elem(&1, 1))) != length(named),
      do: Mix.raise("Machine names collide; select modules explicitly")

    File.mkdir_p!("docs/machines")

    for {module, name} <- named do
      path = "docs/machines/#{name}.md"
      File.write!(path, Board.Fsm.Renderer.document(module, name))
      Mix.shell().info("Generated #{path}")
    end
  end
end
