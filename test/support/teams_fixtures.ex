defmodule Intellispark.TeamsFixtures do
  @moduledoc """
  Test fixtures for Phase 10 Teams resources (TeamMembership,
  KeyConnection, Strength). Pairs with `Intellispark.StudentsFixtures`.
  """

  alias Intellispark.Accounts.{User, UserSchoolMembership}
  alias Intellispark.Teams

  def create_team_membership!(actor, school, student, user, role \\ :coach) do
    {:ok, tm} =
      Teams.create_team_membership(student.id, user.id, role,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    tm
  end

  def create_key_connection!(actor, school, student, connected_user, attrs \\ %{}) do
    {:ok, kc} =
      Teams.create_key_connection(student.id, connected_user.id, attrs,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    kc
  end

  def create_strength!(actor, school, student, description) do
    {:ok, s} =
      Teams.create_strength(student.id, description,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    s
  end

  def register_staff!(school, role \\ :counselor) do
    user =
      Ash.create!(
        User,
        %{
          email: "staff-#{System.unique_integer([:positive])}@sandbox.edu",
          password: "supersecret123",
          password_confirmation: "supersecret123"
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: user.id, school_id: school.id, role: role, source: :manual},
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end
end
