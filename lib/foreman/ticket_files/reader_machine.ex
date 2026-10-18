defmodule Foreman.TicketFiles.ReaderMachine do
  @moduledoc "Coalesced directory hints; only two equal snapshots may be published."
  use Foreman.Fsm, observed_never_invalid: true
  initial(:watching)
  state(:watching)
  state(:settling)
  state(:stopped)
  event(:changed, source: :observed)
  event(:unstable, source: :observed)
  event(:stable, source: :observed)
  event(:lost, source: :observed)
  event(:retry, source: :observed)
  effects([:timer, :publish, :stop])
  transition(:changed, from: :watching, to: :settling, do: [timer: :sample])
  transition(:retry, from: :watching, to: :settling, do: [timer: :retry])
  ignore([:changed, :retry], from: :settling)
  transition(:unstable, from: :settling, to: :stay, do: [timer: :sample])
  transition(:stable, from: :settling, to: :watching, do: [publish: :snapshot])
  transition(:lost, from: [:watching, :settling], to: :stopped, do: [stop: :restart])
  ignore([:stable, :unstable], from: :watching)
  ignore(:any, from: :stopped)
end
