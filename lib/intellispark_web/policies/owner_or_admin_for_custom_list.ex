defmodule IntellisparkWeb.Policies.OwnerOrAdminForCustomList do
  @moduledoc """
  SimpleCheck — allows update / destroy on a CustomList when the actor
  is the list owner OR an admin at the list's school. Admins can clean
  up lists owned by departed staff.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is the list owner or a school admin"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(%{id: user_id} = actor, %{subject: subject}, _opts)
      when is_binary(user_id) do
    list = subject_record(subject)
    tenant = extract_tenant(subject)

    cond do
      is_nil(list) -> false
      list.owner_id == user_id -> true
      tenant && admin_of_school?(actor, tenant) -> true
      true -> false
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp subject_record(%Ash.Changeset{data: %_{} = data}), do: data
  defp subject_record(_), do: nil

  defp extract_tenant(%{tenant: tenant}) when is_binary(tenant), do: tenant
  defp extract_tenant(_), do: nil

  defp admin_of_school?(%{school_memberships: memberships}, school_id)
       when is_list(memberships) do
    Enum.any?(memberships, &(&1.school_id == school_id and &1.role == :admin))
  end

  defp admin_of_school?(_, _), do: false
end
