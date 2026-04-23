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

  def create_external_person!(actor, school, attrs \\ %{}) do
    merged =
      Map.merge(
        %{
          first_name: "Pat",
          last_name: "Parent#{System.unique_integer([:positive])}",
          relationship_kind: :parent
        },
        attrs
      )

    extras = Map.drop(merged, [:first_name, :last_name, :relationship_kind])

    {:ok, ep} =
      Teams.create_external_person(
        merged.first_name,
        merged.last_name,
        merged.relationship_kind,
        extras,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    ep
  end

  def create_key_connection_for_external_person!(actor, school, student, ep, attrs \\ %{}) do
    {:ok, kc} =
      Teams.create_key_connection_for_external_person(student.id, ep.id, attrs,
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
