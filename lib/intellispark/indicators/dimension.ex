defmodule Intellispark.Indicators.Dimension do
  @moduledoc """
  The 13 canonical SEL dimensions used by the Insightfull survey +
  Key Indicators section. Order is load-bearing — it matches the
  display order on the Hub grid + the Insights modal sidebar.
  """

  @dimensions [
    :belonging,
    :connection,
    :decision_making,
    :engagement,
    :readiness,
    :relationship_skills,
    :relationships_adult,
    :relationships_networks,
    :relationships_peer,
    :self_awareness,
    :self_management,
    :social_awareness,
    :well_being
  ]

  @humanised %{
    belonging: "Belonging",
    connection: "Connection",
    decision_making: "Decision Making",
    engagement: "Engagement",
    readiness: "Readiness",
    relationship_skills: "Relationship Skills",
    relationships_adult: "Relationships (Adult)",
    relationships_networks: "Relationships (Networks)",
    relationships_peer: "Relationships (Peer)",
    self_awareness: "Self Awareness",
    self_management: "Self Management",
    social_awareness: "Social Awareness",
    well_being: "Well-Being"
  }

  @spec all() :: [atom()]
  def all, do: @dimensions

  @spec humanize(atom()) :: String.t()
  def humanize(dim) when is_map_key(@humanised, dim), do: Map.fetch!(@humanised, dim)

  @spec from_string(String.t()) :: {:ok, atom()} | :error
  def from_string(str) when is_binary(str) do
    case Enum.find(@dimensions, fn d -> Atom.to_string(d) == str end) do
      nil -> :error
      dim -> {:ok, dim}
    end
  end

  @spec valid?(atom()) :: boolean()
  def valid?(dim), do: is_map_key(@humanised, dim)
end
