defmodule IntellisparkWeb.Policies.DistrictAdminCanInvite do
  @moduledoc """
  SimpleCheck variant of `DistrictAdminOfSchoolInvitation` for the `:invite`
  create action. FilterCheck can't cross a belongs_to relationship on create
  because there's no row yet — so this check reads `school_id` off the
  changeset and loads the school to confirm the actor is a district admin of
  the school's district.
  """

  use Ash.Policy.SimpleCheck

  alias Intellispark.Accounts.School

  def describe(_), do: "actor is a district admin of the invitation's school"

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    authorized?(actor, Ash.Changeset.get_attribute(changeset, :school_id))
  end

  def match?(actor, %{resource: _, subject: %{data: %{school_id: school_id}}}, _opts) do
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
