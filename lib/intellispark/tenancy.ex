defmodule Intellispark.Tenancy do
  @moduledoc """
  Normalizes the tenant identifier that Ash expects when scoping queries by school.

  Accepts a `%School{}`, `school_id` binary, a `%UserSchoolMembership{}`, or a map
  containing `:current_school`. Returns the `school_id` binary.

  `nil` raises — forgetting tenant is a bug, not a silent fallback.

  Phase 2+ resources will declare `multitenancy do strategy :attribute; attribute :school_id end`
  and call `Ash.read!(Student, tenant: Intellispark.Tenancy.to_tenant(actor))`.
  """

  alias Intellispark.Accounts.{School, UserSchoolMembership}

  def to_tenant(%School{id: id}), do: id
  def to_tenant(%UserSchoolMembership{school_id: id}), do: id
  def to_tenant(%{current_school: %School{id: id}}), do: id
  def to_tenant(id) when is_binary(id), do: id

  def to_tenant(other) do
    raise ArgumentError,
          "cannot derive tenant from #{inspect(other)}. " <>
            "Expected a %School{}, a school_id string, a %UserSchoolMembership{}, or a map with :current_school."
  end
end
