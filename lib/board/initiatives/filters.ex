defmodule Board.Initiatives.Filters do
  @moduledoc "Validated URL values for the initiatives query. Empty values mean all."

  def normalize(params, options) when is_map(params) do
    choices = %{
      "project" => Enum.map(options.repos, & &1["key"]),
      "type" => options.types,
      "label" => options.labels,
      "status" => ~w(open closed in_progress blocked deferred),
      "stale" => ["true", "false"]
    }

    Map.new(choices, fn {key, allowed} ->
      value = params[key]
      {key, if(value in allowed, do: value, else: "")}
    end)
    |> Map.put("q", if(is_binary(params["q"]), do: params["q"], else: ""))
  end

  def normalize(_, options), do: normalize(%{}, options)

  def path(filters), do: "/?" <> URI.encode_query(Enum.sort(filters))

  def toggle_project(filters, project) do
    Map.put(filters, "project", if(filters["project"] == project, do: "", else: project))
  end
end
