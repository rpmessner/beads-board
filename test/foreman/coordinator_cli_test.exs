defmodule Foreman.CoordinatorCLITest do
  use ExUnit.Case, async: true
  alias Foreman.CoordinatorCLI

  test "argv chooses resume by default, fresh explicitly, or adoption without launch" do
    assert CoordinatorCLI.parse([]) == {:ok, :resume}
    assert CoordinatorCLI.parse(["--fresh"]) == {:ok, :fresh}
    id = "1edc88cf-b665-4ce3-adc4-f1bd434c64f2"
    assert CoordinatorCLI.parse(["--adopt", id]) == {:ok, {:adopt, id}}

    for args <- [["--fresh", "--adopt", id], ["--adopt", "bad"], ["extra"], ["--unknown"]] do
      assert CoordinatorCLI.parse(args) == {:error, :usage}
    end
  end
end
