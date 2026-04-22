defmodule IntellisparkWeb.Policies.DistrictAdminForSchoolCreate do
  @moduledoc """
  SimpleCheck variant of `DistrictAdminOfSchool` for `School.:create`.
  FilterCheck can't authorize creates (no row yet), so this check reads
  the `district_id` off the changeset and matches it against the actor's
  own `district_id` + `:admin` membership.
  """

  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor is a district admin of the school's district (create path)"

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    district_id =
      Ash.Changeset.get_attribute(changeset, :district_id) ||
        Ash.Changeset.get_argument(changeset, :district_id)

    admin?(actor) and district_id != nil and
      district_id == Map.get(actor, :district_id)
  end

  def match?(_actor, _context, _opts), do: false

  defp admin?(actor) do
    actor
    |> Map.get(:school_memberships, [])
    |> List.wrap()
    |> Enum.any?(&(&1.role == :admin))
  end
end
