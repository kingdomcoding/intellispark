defmodule IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool do
  @moduledoc """
  SimpleCheck — matches actors with an admin / counselor / social_worker /
  clinician / psychologist membership at the tenant school. Used on
  Student reads so clinical staff bypass the teacher-team scoping
  filter (Phase 10).
  """

  use Ash.Policy.SimpleCheck

  @clinical_roles [:admin, :counselor, :social_worker, :clinician, :psychologist]

  @impl true
  def describe(_opts), do: "actor has a clinical role at this school"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: subject}, _opts) do
    tenant = extract_tenant(subject)

    memberships =
      actor
      |> Map.get(:school_memberships, [])
      |> List.wrap()

    tenant != nil and
      Enum.any?(memberships, fn m ->
        m.school_id == tenant and m.role in @clinical_roles
      end)
  end

  def match?(_actor, _context, _opts), do: false

  defp extract_tenant(%{tenant: tenant}), do: tenant
  defp extract_tenant(_), do: nil
end
