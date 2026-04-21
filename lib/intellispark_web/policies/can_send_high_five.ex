defmodule IntellisparkWeb.Policies.CanSendHighFive do
  @moduledoc """
  SimpleCheck used on HighFive.:send_to_student + :bulk_send_to_students.
  Accepts any staff member (teacher / counselor / clinician /
  social_worker / admin) on the student's school (the tenant).
  """

  use Ash.Policy.SimpleCheck

  @staff_roles [:teacher, :counselor, :clinician, :social_worker, :admin]

  def describe(_), do: "actor is staff on the student's school"

  def match?(nil, _, _), do: false

  def match?(actor, %{subject: %{tenant: tenant}}, _opts) when is_binary(tenant) do
    roles_in_school =
      actor
      |> Map.get(:school_memberships, [])
      |> List.wrap()
      |> Enum.filter(&(&1.school_id == tenant))
      |> Enum.map(& &1.role)

    Enum.any?(roles_in_school, &(&1 in @staff_roles))
  end

  def match?(_actor, _context, _opts), do: false
end
