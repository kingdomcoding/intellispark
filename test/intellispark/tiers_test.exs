defmodule Intellispark.TiersTest do
  use ExUnit.Case, async: true

  alias Intellispark.Tiers

  test "xello_integration is PRO-only" do
    refute Tiers.allows?(:starter, :xello_integration)
    refute Tiers.allows?(:plus, :xello_integration)
    assert Tiers.allows?(:pro, :xello_integration)
  end

  test "custom_lists cap scales with tier" do
    assert Tiers.cap_for(:starter, :custom_lists) == 5
    assert Tiers.cap_for(:plus, :custom_lists) == 50
    assert Tiers.cap_for(:pro, :custom_lists) == :unlimited
  end

  test "unknown feature denies + caps at 0" do
    refute Tiers.allows?(:pro, :unknown_feature)
    assert Tiers.cap_for(:pro, :unknown_feature) == 0
  end
end
