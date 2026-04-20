defmodule IntellisparkWeb.Policies.StaffReadsStudentsInSchool do
  @moduledoc """
  Filters students (and other school-scoped resources) to the set of schools
  the actor has a UserSchoolMembership in. District admins additionally see
  every school in their district (handled by a second policy when needed).
  """

  use Ash.Policy.FilterCheck

  require Ash.Expr

  def describe(_), do: "actor has a membership in the row's school"

  def filter(nil, _authorizer, _opts), do: Ash.Expr.expr(false)

  def filter(actor, _authorizer, _opts) do
    member_school_ids = member_school_ids(actor)

    if member_school_ids == [] do
      Ash.Expr.expr(false)
    else
      Ash.Expr.expr(school_id in ^member_school_ids)
    end
  end

  defp member_school_ids(actor) do
    actor
    |> Map.get(:school_memberships, [])
    |> List.wrap()
    |> Enum.map(& &1.school_id)
  end
end
