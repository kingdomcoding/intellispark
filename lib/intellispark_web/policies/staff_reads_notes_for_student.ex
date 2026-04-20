defmodule IntellisparkWeb.Policies.StaffReadsNotesForStudent do
  @moduledoc """
  FilterCheck on Note reads. Scopes by the actor's school memberships and
  gates sensitive? == true behind clinical roles
  (admin / counselor / clinician / social_worker). Teachers see only
  non-sensitive notes in their school.
  """

  use Ash.Policy.FilterCheck

  require Ash.Expr

  @clinical_roles [:admin, :counselor, :clinician, :social_worker]

  def describe(_), do: "staff reads notes in their school; clinical roles also see sensitive"

  def filter(nil, _, _), do: Ash.Expr.expr(false)

  def filter(actor, _authorizer, _opts) do
    memberships = actor |> Map.get(:school_memberships, []) |> List.wrap()
    school_ids = Enum.map(memberships, & &1.school_id)
    roles = memberships |> Enum.map(& &1.role) |> Enum.uniq()
    clinical? = Enum.any?(roles, &(&1 in @clinical_roles))

    cond do
      school_ids == [] ->
        Ash.Expr.expr(false)

      clinical? ->
        Ash.Expr.expr(school_id in ^school_ids)

      true ->
        Ash.Expr.expr(school_id in ^school_ids and sensitive? == false)
    end
  end
end
