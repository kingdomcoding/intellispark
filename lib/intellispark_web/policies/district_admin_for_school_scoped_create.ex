defmodule IntellisparkWeb.Policies.DistrictAdminForSchoolScopedCreate do
  @moduledoc """
  Generic SimpleCheck for `:create` actions on resources that belong to a
  School. Reads `school_id` off the changeset (attribute or argument),
  looks up the school, and matches if the actor is a district admin
  (`district_id` match + `:admin` membership) of that school's district.

  Use on any create action where a FilterCheck can't be applied (because
  there's no row yet) and the target scope is determined by `school_id`.
  """

  use Ash.Policy.SimpleCheck

  alias Intellispark.Accounts.School

  def describe(_), do: "actor is a district admin of the target school's district (create)"

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    school_id =
      Ash.Changeset.get_attribute(changeset, :school_id) ||
        Ash.Changeset.get_argument(changeset, :school_id)

    authorized?(actor, school_id)
  end

  def match?(_actor, _context, _opts), do: false

  defp authorized?(_actor, nil), do: false

  defp authorized?(actor, school_id) do
    with true <- admin?(actor),
         {:ok, %School{district_id: district_id}} <-
           Ash.get(School, school_id, authorize?: false) do
      district_id && district_id == Map.get(actor, :district_id)
    else
      _ -> false
    end
  end

  defp admin?(actor) do
    actor
    |> Map.get(:school_memberships, [])
    |> List.wrap()
    |> Enum.any?(&(&1.role == :admin))
  end
end
