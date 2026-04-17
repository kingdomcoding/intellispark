defmodule IntellisparkWeb.Policies.DistrictAdminOfUser do
  @moduledoc """
  Filter check: matches users whose `district_id` equals the actor's `district_id`,
  but only when the actor holds an `:admin` role on at least one of their school
  memberships.

  Requires `:school_memberships` and `:district_id` to be loaded on the actor.
  """

  use Ash.Policy.FilterCheck

  require Ash.Expr

  def describe(_), do: "actor is a district-level admin of the target user's district"

  def filter(nil, _authorizer, _opts), do: Ash.Expr.expr(false)

  def filter(actor, _authorizer, _opts) do
    district_id = Map.get(actor, :district_id)

    if district_id && admin?(actor) do
      Ash.Expr.expr(district_id == ^district_id)
    else
      Ash.Expr.expr(false)
    end
  end

  defp admin?(actor) do
    actor
    |> Map.get(:school_memberships, [])
    |> List.wrap()
    |> Enum.any?(&(&1.role == :admin))
  end
end
