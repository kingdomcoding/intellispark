defmodule IntellisparkWeb.Policies.StaffEditsStudentsInSchool do
  @moduledoc """
  FilterCheck for edits. Phase 2 is permissive: any staff member with a
  membership in the school can create/update/destroy students in it.
  Class-based tightening (teachers only edit students in their classes)
  deferred to Phase 10 Teams.
  """

  use Ash.Policy.FilterCheck

  require Ash.Expr

  def describe(_), do: "actor has a membership in the row's school"

  def filter(nil, _authorizer, _opts), do: Ash.Expr.expr(false)

  def filter(actor, _authorizer, _opts) do
    member_school_ids =
      actor
      |> Map.get(:school_memberships, [])
      |> List.wrap()
      |> Enum.map(& &1.school_id)

    if member_school_ids == [] do
      Ash.Expr.expr(false)
    else
      Ash.Expr.expr(school_id in ^member_school_ids)
    end
  end
end
