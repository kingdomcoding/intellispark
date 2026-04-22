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
  def match?(%{school_memberships: memberships}, subject, _opts)
      when is_list(memberships) do
    tenant = subject.subject.tenant

    Enum.any?(memberships, fn m ->
      m.school_id == tenant and m.role in @clinical_roles
    end)
  end

  def match?(_, _, _), do: false
end
