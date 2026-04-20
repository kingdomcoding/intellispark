defmodule IntellisparkWeb.Policies.AssigneeOrAdminForAction do
  @moduledoc """
  SimpleCheck used on Action.complete. Accepts only if the actor is the
  assignee or holds an :admin role.
  """

  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor is the assignee or an admin"

  def match?(nil, _, _), do: false

  def match?(actor, %{subject: %{data: %{assignee_id: assignee_id}}}, _opts) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)
    actor.id == assignee_id or Enum.any?(roles, &(&1 == :admin))
  end

  def match?(_actor, _context, _opts), do: false
end
