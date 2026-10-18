defmodule ForemanWeb.LiveViewClockTest do
  use ForemanWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "LiveView signing tolerates a backwards clock step without replacing verification" do
    # Fixed instants: the issuer is 39 ms ahead of the verifier after a clock step.
    issued_at = 1_792_325_498_740
    verifier_now = 1_792_325_498_701
    ForemanWeb.LiveViewClock.install(fn -> issued_at end)

    token = Phoenix.LiveView.Static.sign_token(ForemanWeb.Endpoint, %{probe: :clock})
    [_, encoded, _signature] = String.split(token, ".")

    {payload, signed_at, _max_age} =
      encoded |> Base.url_decode64!(padding: false) |> :erlang.binary_to_term([:safe])

    assert signed_at == issued_at - 1_000
    assert signed_at <= verifier_now

    assert {:ok, ^payload} =
             Phoenix.Token.verify(ForemanWeb.Endpoint, salt(), token, max_age: :infinity)
  end

  @tag :production_token_clock
  test "production rejects an authentic future session and reloads the bare route", %{conn: conn} do
    conn = get(conn, "/")

    [token] =
      conn.resp_body
      |> LazyHTML.from_document()
      |> LazyHTML.query("[data-phx-main]")
      |> LazyHTML.attribute("data-phx-session")

    {:ok, payload} = Phoenix.Token.verify(ForemanWeb.Endpoint, salt(), token, max_age: :infinity)

    future =
      Phoenix.Token.sign(ForemanWeb.Endpoint, salt(), payload,
        signed_at: System.os_time(:second) + 3_600
      )

    conn = %{conn | resp_body: String.replace(conn.resp_body, token, future)}
    assert {:error, {:redirect, %{to: "http://www.example.com/"}}} = live(conn)
  end

  test "the signing allowance does not bypass invalid signatures or expiry" do
    token = Phoenix.LiveView.Static.sign_token(ForemanWeb.Endpoint, %{probe: :signature})
    [header, encoded, signature] = String.split(token, ".")
    <<first, rest::binary>> = signature
    bad_signature = <<Bitwise.bxor(first, 1), rest::binary>>
    tampered = Enum.join([header, encoded, bad_signature], ".")

    assert {:error, :invalid} =
             Phoenix.LiveView.Static.verify_token(ForemanWeb.Endpoint, tampered)

    expired =
      Phoenix.Token.sign(ForemanWeb.Endpoint, salt(), {Phoenix.LiveView.Static.token_vsn(), %{}},
        signed_at: System.os_time(:second) - 1_209_660
      )

    assert {:error, :expired} = Phoenix.LiveView.Static.verify_token(ForemanWeb.Endpoint, expired)
  end

  test "other token salts and explicit signing options keep their original behavior" do
    ForemanWeb.LiveViewClock.install(fn -> 1_000 end)
    other = Phoenix.Token.sign(ForemanWeb.Endpoint, "unrelated", :payload)
    [_, encoded, _signature] = String.split(other, ".")

    {_, signed_at, _} =
      encoded |> Base.url_decode64!(padding: false) |> :erlang.binary_to_term([:safe])

    assert signed_at > 1_000

    assert {:ok, :payload} =
             Phoenix.Token.verify(ForemanWeb.Endpoint, "unrelated", other, max_age: :infinity)

    explicit = Phoenix.Token.sign(ForemanWeb.Endpoint, salt(), :payload, signed_at: 1)
    assert {:error, :expired} = Phoenix.Token.verify(ForemanWeb.Endpoint, salt(), explicit)
  end

  test "a test's clock allowance does not leak to an independent process" do
    ForemanWeb.LiveViewClock.install(fn -> 1_000 end)
    parent = self()

    pid =
      start_supervised!({Task,
       fn ->
         # Tasks inherit the test's callers; model an unrelated test process.
         Process.delete(:"$callers")
         token = Phoenix.LiveView.Static.sign_token(ForemanWeb.Endpoint, %{probe: :isolated})
         send(parent, {:independent_token, token})
       end})

    # The task sends before it exits, so its exit guarantees the token is in the mailbox;
    # the default 100 ms assert_receive was too short under full-suite load.
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5_000
    assert_received {:independent_token, token}
    [_, encoded, _signature] = String.split(token, ".")

    {_, signed_at, _} =
      encoded |> Base.url_decode64!(padding: false) |> :erlang.binary_to_term([:safe])

    assert signed_at > 1_000
  end

  defp salt, do: ForemanWeb.Endpoint.config(:live_view)[:signing_salt]
end
