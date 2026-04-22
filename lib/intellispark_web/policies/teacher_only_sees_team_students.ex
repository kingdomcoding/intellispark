defmodule IntellisparkWeb.Policies.TeacherOnlySeesTeamStudents do
  @moduledoc """
  FilterCheck that restricts Student reads to rows where the actor
  appears in `team_memberships`. Combined with
  `AdminOrClinicalRoleInSchool` in an `authorize_if / authorize_if`
  chain — admins / counselors / clinical staff bypass this filter;
  teachers are scoped to their team students.
  """

  use Ash.Policy.FilterCheck

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor is on the student's team (teacher scoping)"

  @impl true
  def filter(%{id: user_id}, _auth, _opts) when is_binary(user_id) do
    Ash.Expr.expr(exists(team_memberships, user_id == ^user_id))
  end

  def filter(_actor, _auth, _opts), do: Ash.Expr.expr(false)
end
