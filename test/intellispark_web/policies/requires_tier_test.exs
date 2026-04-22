defmodule IntellisparkWeb.Policies.RequiresTierTest do
  use ExUnit.Case, async: true

  alias IntellisparkWeb.Policies.RequiresTier

  test "nil actor denies" do
    refute RequiresTier.match?(nil, %{}, tier: :pro)
    refute RequiresTier.match?(nil, %{}, tier: :plus)
    refute RequiresTier.match?(nil, %{}, tier: :starter)
  end

  test "actor with PRO tier passes every required level" do
    actor = fake_actor(:pro)

    assert RequiresTier.match?(actor, %{}, tier: :starter)
    assert RequiresTier.match?(actor, %{}, tier: :plus)
    assert RequiresTier.match?(actor, %{}, tier: :pro)
  end

  test "actor with PLUS tier passes plus + starter, fails pro" do
    actor = fake_actor(:plus)

    assert RequiresTier.match?(actor, %{}, tier: :starter)
    assert RequiresTier.match?(actor, %{}, tier: :plus)
    refute RequiresTier.match?(actor, %{}, tier: :pro)
  end

  test "actor with STARTER tier passes only starter" do
    actor = fake_actor(:starter)

    assert RequiresTier.match?(actor, %{}, tier: :starter)
    refute RequiresTier.match?(actor, %{}, tier: :plus)
    refute RequiresTier.match?(actor, %{}, tier: :pro)
  end

  test "actor without current_school denies" do
    actor = %{id: "abc"}

    refute RequiresTier.match?(actor, %{}, tier: :starter)
  end

  defp fake_actor(tier) do
    %{id: "user-1", current_school: %{subscription: %{tier: tier}}}
  end
end
