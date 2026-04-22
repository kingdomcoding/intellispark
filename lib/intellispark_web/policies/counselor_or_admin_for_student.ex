defmodule IntellisparkWeb.Policies.CounselorOrAdminForStudent do
  @moduledoc """
  SimpleCheck — authorizes when the actor has an :admin / :counselor /
  :social_worker / :clinician membership at the tenant school. Used by
  Phase 10 TeamMembership + KeyConnection mutation policies so only
  clinically-trusted roles can add / edit / remove team relationships.
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
