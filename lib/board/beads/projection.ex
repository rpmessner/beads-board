defmodule Board.Beads.Projection do
  @moduledoc """
  Transactional, droppable projection of complete successful exports.

  Raw JSONB retains comments, edges and future fields without lossy re-encoding
  of enum values. `Export.decode/1` supplies normalized values to consumers.
  The overlay has no foreign key to this cache; replacing or deleting cache rows
  never deletes process facts. This module does not open a beads store.

  Advisory transaction locks serialize replacement for a configured repo key,
  including the initial insert. They are database locks, not store locks and not
  a substitute for physical-repository single flight in the future read worker.
  """
  import Ecto.Query
  alias Board.Beads.Export
  alias Board.Repo

  def replace(repo_key, output) when is_binary(repo_key) and byte_size(repo_key) > 0 do
    with {:ok, export} <- Export.decode(output) do
      Repo.transaction(fn ->
        Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
          "board:projection:" <> repo_key
        ])

        hash =
          Repo.one(from r in "bead_repos", where: r.key == ^repo_key, select: r.export_sha256)

        if hash == export.sha256 do
          :unchanged
        else
          replace_rows(repo_key, export)
          :changed
        end
      end)
    end
  end

  def list_raw(repo_key) do
    Repo.all(
      from b in "beads", where: b.repo_key == ^repo_key, order_by: b.bead_id, select: b.raw
    )
  end

  defp replace_rows(repo_key, export) do
    now = DateTime.utc_now()

    Repo.insert_all(
      "bead_repos",
      [%{key: repo_key, export_sha256: export.sha256, synced_at: now}],
      on_conflict: {:replace, [:export_sha256, :synced_at]},
      conflict_target: [:key]
    )

    rows = Enum.map(export.beads, &%{repo_key: repo_key, bead_id: &1.bead_id, raw: &1.raw})

    Repo.insert_all("beads", rows,
      on_conflict: {:replace, [:raw]},
      conflict_target: [:repo_key, :bead_id]
    )

    ids = Enum.map(export.beads, & &1.bead_id)
    Repo.delete_all(from b in "beads", where: b.repo_key == ^repo_key and b.bead_id not in ^ids)

    Repo.update_all(
      from(t in "tickets",
        where: t.repo_key == ^repo_key and t.bead_id not in ^ids and is_nil(t.orphaned_at)
      ),
      set: [orphaned_at: now]
    )

    Repo.update_all(
      from(t in "tickets",
        where: t.repo_key == ^repo_key and t.bead_id in ^ids and not is_nil(t.orphaned_at)
      ),
      set: [orphaned_at: nil]
    )
  end
end
