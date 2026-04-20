defmodule IntellisparkWeb.Policies.AssigneeOrOpenerOrAdminForAction do
  @moduledoc """
  SimpleCheck used on Action.update / Action.cancel. Accepts if the actor is
  the current assignee, the opener, or holds an :admin role.
  """

  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor is the assignee or opener, or an admin"

  def match?(nil, _, _), do: false

  def match?(
        actor,
        %{subject: %{data: %{assignee_id: assignee_id, opened_by_id: opener_id}}},
        _opts
      ) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)
    actor.id in [assignee_id, opener_id] or Enum.any?(roles, &(&1 == :admin))
  end

  def match?(_actor, _context, _opts), do: false
end
