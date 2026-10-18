defmodule Board.Events do
  @moduledoc """
  Postgres-backed invalidations shared by web and worker nodes without clustering.

  LiveViews subscribe to Oban's notifier, receiving
  `{:notification, :board_events, %{"version" => 1, "kind" => kind, "key" => key}}`.
  Only identities travel here; consumers reload authoritative data from Postgres.
  Never broadcast ticket bodies, config contents or filesystem paths.

  Call inside the data transaction for atomic commit visibility, or after commit.
  LISTEN/NOTIFY is not a durable event log: subscribers must fetch a fresh snapshot
  on mount/reconnect and periodically reconcile to recover missed notifications.
  Config's last-good snapshot must also live in Postgres before a worker can
  announce it; node-local memory is not a cross-role config store.
  """

  @kinds %{
    config_changed: "config_changed",
    forge_changed: "forge_changed",
    merge_changed: "merge_changed",
    forge_requested: "forge_requested",
    sync_status_changed: "sync_status_changed",
    projection_changed: "projection_changed",
    overlay_changed: "overlay_changed",
    sync_requested: "sync_requested"
  }

  def subscribe(instance \\ Oban), do: Oban.Notifier.listen(instance, :board_events)
  def unsubscribe(instance \\ Oban), do: Oban.Notifier.unlisten(instance, :board_events)

  def broadcast(kind, key, instance \\ Oban) when is_binary(key) do
    Oban.Notifier.notify(instance, :board_events, %{
      version: 1,
      kind: Map.fetch!(@kinds, kind),
      key: key
    })
  end
end
