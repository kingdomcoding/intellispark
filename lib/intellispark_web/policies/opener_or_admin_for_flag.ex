defmodule IntellisparkWeb.Policies.OpenerOrAdminForFlag do
  @moduledoc """
  SimpleCheck used on Flag.reopen. Accepts if the actor opened the flag
  originally, OR holds an :admin role on any membership.
  """

  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor opened this flag or is an admin"

  def match?(nil, _, _), do: false

  def match?(actor, %{subject: %{data: %{opened_by_id: opener_id}}}, _opts) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)
    actor.id == opener_id or Enum.any?(roles, &(&1 == :admin))
  end

  def match?(_actor, _context, _opts), do: false
end
