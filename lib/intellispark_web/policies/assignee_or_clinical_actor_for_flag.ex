defmodule IntellisparkWeb.Policies.AssigneeOrClinicalActorForFlag do
  @moduledoc """
  SimpleCheck used on Flag.close_with_resolution. Accepts if the actor is
  a current (not cleared) assignee on the flag, OR holds a clinical role
  (admin / counselor) in any of their school memberships.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Intellispark.Flags.FlagAssignment

  @clinical_roles [:admin, :counselor]

  def describe(_), do: "actor is a current assignee or has a clinical role"

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: %{data: %{id: flag_id, school_id: school_id}}}, _opts)
      when is_binary(flag_id) and is_binary(school_id) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)

    cond do
      Enum.any?(roles, &(&1 in @clinical_roles)) ->
        true

      true ->
        assignee?(flag_id, actor.id, school_id)
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp assignee?(flag_id, user_id, tenant) do
    case FlagAssignment
         |> Ash.Query.filter(flag_id == ^flag_id and user_id == ^user_id and is_nil(cleared_at))
         |> Ash.Query.set_tenant(tenant)
         |> Ash.read(authorize?: false) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
