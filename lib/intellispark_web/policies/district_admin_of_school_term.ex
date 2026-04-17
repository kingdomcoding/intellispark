defmodule IntellisparkWeb.Policies.DistrictAdminOfSchoolTerm do
  @moduledoc """
  Filter check: matches school terms whose school belongs to the actor's
  district, and only when the actor holds an `:admin` role on at least one
  of their school memberships.
  """

  use Ash.Policy.FilterCheck

  require Ash.Expr

  def describe(_), do: "actor is a district-admin covering the school term's school"

  def filter(nil, _authorizer, _opts), do: Ash.Expr.expr(false)

  def filter(actor, _authorizer, _opts) do
    district_id = Map.get(actor, :district_id)

    if district_id && admin?(actor) do
      Ash.Expr.expr(school.district_id == ^district_id)
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
