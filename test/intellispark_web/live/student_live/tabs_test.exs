defmodule IntellisparkWeb.StudentLive.TabsTest do
  use ExUnit.Case, async: true

  alias IntellisparkWeb.StudentLive.Tabs

  @uuid "11111111-2222-3333-4444-555555555555"

  test "from_param defaults to :profile" do
    assert Tabs.from_param(nil) == :profile
    assert Tabs.from_param("") == :profile
    assert Tabs.from_param("profile") == :profile
    assert Tabs.from_param("garbage") == :profile
  end

  test "from_param parses :about" do
    assert Tabs.from_param("about") == :about
  end

  test "from_param parses {:flag, uuid} with valid UUID" do
    assert Tabs.from_param("flag:#{@uuid}") == {:flag, @uuid}
  end

  test "from_param parses {:support, uuid} with valid UUID" do
    assert Tabs.from_param("support:#{@uuid}") == {:support, @uuid}
  end

  test "from_param falls back to :profile on invalid UUID" do
    assert Tabs.from_param("flag:not-a-uuid") == :profile
    assert Tabs.from_param("support:also-not") == :profile
  end

  test "to_param round-trips through from_param for every tab kind" do
    for tab <- [:profile, :about, {:flag, @uuid}, {:support, @uuid}] do
      assert tab |> Tabs.to_param() |> Tabs.from_param() == tab
    end
  end
end
