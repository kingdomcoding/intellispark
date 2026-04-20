defmodule IntellisparkWeb.Policies.ProviderOrClinicalActorForSupport do
  @moduledoc """
  SimpleCheck used on Support.accept / decline / complete / update. Accepts
  if the actor is the assigned provider_staff, or holds a clinical role
  (:admin, :counselor, :clinician, :social_worker).
  """

  use Ash.Policy.SimpleCheck

  @clinical_roles [:admin, :counselor, :clinician, :social_worker]

  def describe(_), do: "actor is the provider staff, or holds a clinical role"

  def match?(nil, _, _), do: false

  def match?(actor, %{subject: %{data: %{provider_staff_id: provider_id}}}, _opts) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)
    actor.id == provider_id or Enum.any?(roles, &(&1 in @clinical_roles))
  end

  def match?(_actor, _context, _opts), do: false
end
