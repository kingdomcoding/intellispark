defmodule IntellisparkWeb.Policies.ActorBelongsToTenantSchool do
  @moduledoc """
  SimpleCheck variant of StaffEditsStudentsInSchool used on actions where a
  FilterCheck can't be applied (create, generic actions). Returns true when
  the actor has a membership row matching the subject's tenant (school_id).
  """

  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor has a membership in the tenant school"

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: subject}, _opts) do
    tenant = extract_tenant(subject)

    memberships =
      actor
      |> Map.get(:school_memberships, [])
      |> List.wrap()

    tenant != nil and Enum.any?(memberships, &(&1.school_id == tenant))
  end

  def match?(_actor, _context, _opts), do: false

  defp extract_tenant(%{tenant: tenant}), do: tenant
  defp extract_tenant(_), do: nil
end
