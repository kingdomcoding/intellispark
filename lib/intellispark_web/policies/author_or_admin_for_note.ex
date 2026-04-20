defmodule IntellisparkWeb.Policies.AuthorOrAdminForNote do
  @moduledoc """
  SimpleCheck used on Note.update / pin / unpin. Accepts if the actor is
  the author, or holds an :admin role.
  """

  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor authored this note or is an admin"

  def match?(nil, _, _), do: false

  def match?(actor, %{subject: %{data: %{author_id: author_id}}}, _opts) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)
    actor.id == author_id or Enum.any?(roles, &(&1 == :admin))
  end

  def match?(_actor, _context, _opts), do: false
end
