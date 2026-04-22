defmodule IntellisparkWeb.Policies.RequiresTier do
  @moduledoc """
  SimpleCheck that succeeds when the actor's current school has a
  subscription tier >= the required tier. Usage:

      authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}

  The actor must carry `current_school.subscription.tier`. The live
  user auth loader assigns this on mount; controllers that gate via
  this policy must load it the same way.
  """

  use Ash.Policy.SimpleCheck

  def describe(opts), do: "actor's school has tier >= #{inspect(opts[:tier])}"

  def match?(nil, _context, _opts), do: false

  def match?(actor, _context, opts) do
    required = Keyword.fetch!(opts, :tier)

    case current_tier(actor) do
      nil -> false
      tier -> tier_rank(tier) >= tier_rank(required)
    end
  end

  defp current_tier(actor) do
    case Map.get(actor, :current_school) do
      %{subscription: %{tier: tier}} -> tier
      _ -> nil
    end
  end

  defp tier_rank(:starter), do: 0
  defp tier_rank(:plus), do: 1
  defp tier_rank(:pro), do: 2
  defp tier_rank(_), do: -1
end
