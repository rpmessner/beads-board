defmodule Foreman.NotificationPermission do
  @moduledoc "Browser permission lifecycle; the only prompt effect follows an explicit click."
  use Foreman.Fsm
  initial(:unavailable)
  state(:unavailable)
  state(:default)
  state(:requesting)
  state(:granted)
  state(:denied)
  event(:default, source: :observed)
  event(:granted, source: :observed)
  event(:denied, source: :observed)
  event(:unavailable, source: :observed)
  event(:click)
  event(:dismissed, source: :observed)
  effects([:prompt])
  transition(:click, from: :default, to: :requesting, do: [prompt: :permission])
  transition(:default, from: :requesting, to: :stay)
  transition(:default, from: :any, to: :default)
  transition(:dismissed, from: :requesting, to: :default)
  ignore(:dismissed, from: :any)
  transition(:granted, from: :any, to: :granted)
  transition(:denied, from: :any, to: :denied)
  transition(:unavailable, from: :any, to: :unavailable)
  ignore(:click, from: :any)

  @doc "Unguarded transitions compiled for the browser's small effect interpreter."
  def browser_table do
    Map.new(__fsm__(:states), fn state ->
      {state,
       Map.new(__fsm__(:events), fn event ->
         {next, effects} = step(state, event, %{})
         {event, %{state: next, prompt: Keyword.has_key?(effects, :prompt)}}
       end)}
    end)
  end
end
