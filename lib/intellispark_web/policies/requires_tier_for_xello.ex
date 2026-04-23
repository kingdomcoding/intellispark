defmodule IntellisparkWeb.Policies.RequiresTierForXello do
  @moduledoc """
  SimpleCheck wrapping `RequiresTier(:pro)` — only fires when the
  IntegrationProvider being created is `provider_type: :xello`. Other
  provider types pass through. Used on `IntegrationProvider.:create`.
  """

  use Ash.Policy.SimpleCheck

  alias IntellisparkWeb.Policies.RequiresTier

  def describe(_), do: "Xello provider requires PRO tier"

  def match?(actor, %{changeset: %Ash.Changeset{} = cs} = context, _opts) do
    case Ash.Changeset.get_attribute(cs, :provider_type) do
      :xello -> RequiresTier.match?(actor, context, tier: :pro)
      _ -> true
    end
  end

  def match?(_actor, _context, _opts), do: true
end
