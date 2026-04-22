defmodule Intellispark.Tiers do
  @moduledoc """
  Compile-time feature matrix. Each entry names a feature, its minimum
  tier (`:starter | :plus | :pro`), and an optional cap. Callers consult
  via `allows?/2` + `cap_for/2`. Downstream modules (CustomList,
  AutomationRule, XelloProvider) gate off these.
  """

  @tiers [:starter, :plus, :pro]

  @features %{
    xello_integration: %{min_tier: :pro, cap: nil},
    insights_export: %{min_tier: :pro, cap: nil},
    automation_rules: %{min_tier: :plus, cap: 25},
    custom_lists: %{min_tier: :starter, cap: 5},
    weekly_digest: %{min_tier: :starter, cap: nil},
    bulk_high_fives: %{min_tier: :plus, cap: nil},
    api_access: %{min_tier: :pro, cap: nil}
  }

  @tier_caps %{
    custom_lists: %{starter: 5, plus: 50, pro: :unlimited},
    automation_rules: %{starter: 0, plus: 25, pro: :unlimited}
  }

  def allows?(tier, feature) when tier in @tiers do
    case Map.get(@features, feature) do
      nil -> false
      %{min_tier: min} -> tier_rank(tier) >= tier_rank(min)
    end
  end

  def allows?(_tier, _feature), do: false

  def cap_for(tier, feature) when tier in @tiers do
    case Map.get(@tier_caps, feature) do
      nil ->
        case Map.get(@features, feature) do
          %{cap: nil} -> :unlimited
          %{cap: n} -> n
          _ -> 0
        end

      overrides ->
        Map.get(overrides, tier, 0)
    end
  end

  def cap_for(_tier, _feature), do: 0

  def all, do: @tiers

  def label(:starter), do: "Starter"
  def label(:plus), do: "Plus"
  def label(:pro), do: "Pro"

  defp tier_rank(:starter), do: 0
  defp tier_rank(:plus), do: 1
  defp tier_rank(:pro), do: 2
end
