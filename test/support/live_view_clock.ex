defmodule BoardWeb.LiveViewClock do
  @moduledoc "Test-only LiveView signing allowance for small backwards OS clock steps."

  def install(now_ms \\ fn -> System.os_time(:millisecond) end) do
    salt = BoardWeb.Endpoint.config(:live_view)[:signing_salt]

    Mimic.stub(Phoenix.Token, :sign, fn context, token_salt, data ->
      if context == BoardWeb.Endpoint and token_salt == salt do
        Phoenix.Token.sign(context, token_salt, data, signed_at: (now_ms.() - 1_000) / 1000)
      else
        Mimic.call_original(Phoenix.Token, :sign, [context, token_salt, data])
      end
    end)
  end
end
