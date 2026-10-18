defmodule Foreman.Markdown do
  @moduledoc """
  GFM with raw HTML omitted (MDEx's unsafe rendering remains disabled).
  Only renderer-generated highlighting styles and disabled checkboxes are emitted.
  """
  @options [
    extension: [
      header_ids: "",
      table: true,
      tasklist: true,
      strikethrough: true,
      autolink: true,
      footnotes: true
    ],
    render: [unsafe: false, escape: false],
    syntax_highlight: [
      formatter:
        {:html_multi_themes,
         themes: [light: "github_light", dark: "github_dark"], css_variable_prefix: "--lumis"}
    ]
  ]

  def render(text, opts \\ [])

  def render(text, _opts) when is_binary(text) and byte_size(text) > 1_048_576,
    do: "<p>Content too large</p>"

  def render(nil, _opts), do: ""

  def render(text, opts) do
    text
    |> MDEx.parse_document!(@options)
    |> MDEx.traverse_and_update(fn
      %MDEx.Link{url: url} = link -> %{link | url: link_url(url, opts)}
      node -> node
    end)
    |> MDEx.to_html!()
  end

  def viewer_path(repo, path),
    do:
      "/documents/" <>
        URI.encode(repo, &URI.char_unreserved?/1) <> "?" <> URI.encode_query(%{"path" => path})

  defp relative_path(path, base) do
    if Path.type(path) == :absolute or Path.type(base) == :absolute do
      {:ok, Path.expand(path, Path.dirname(base))}
    else
      root = "/__foreman_document_root__"
      full = Path.expand(path, Path.dirname(Path.join(root, base)))

      if String.starts_with?(full, root <> "/"),
        do: {:ok, Path.relative_to(full, root)},
        else: :error
    end
  end

  defp link_url(url, opts) do
    uri = URI.parse(url)

    cond do
      uri.scheme in ["http", "https", "mailto"] ->
        url

      uri.scheme != nil or uri.host != nil ->
        ""

      is_nil(uri.path) or uri.path == "" ->
        url

      opts[:repo] && String.downcase(Path.extname(uri.path)) == ".md" ->
        case relative_path(URI.decode(uri.path), opts[:path] || "README.md") do
          {:ok, path} ->
            viewer_path(opts[:repo], path) <>
              if(uri.fragment, do: "#" <> URI.encode(uri.fragment), else: "")

          :error ->
            ""
        end

      true ->
        ""
    end
  end
end
