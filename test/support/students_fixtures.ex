defmodule Intellispark.StudentsFixtures do
  @moduledoc """
  Test fixtures for Phase 2 resources. Creates a Sandbox district + one
  or two schools + an admin with memberships, then exposes helpers for
  students/tags/statuses/custom_lists so each test file doesn't have to
  rebuild the same graph.
  """

  alias Intellispark.Accounts.{District, School, User, UserSchoolMembership}
  alias Intellispark.Students.{CustomList, Status, Student, StudentTag, Tag}

  def setup_world do
    {:ok, district} =
      Ash.create(District, %{name: "Sandbox ISD", slug: "sandbox"}, authorize?: false)

    {:ok, school} =
      Ash.create(
        School,
        %{name: "Sandbox High", slug: "sh", district_id: district.id},
        authorize?: false
      )

    admin =
      register!("admin@sandbox.edu", "supersecret123")
      |> attach_district!(district.id)
      |> with_membership!(school.id, :admin)

    %{district: district, school: school, admin: admin}
  end

  def add_second_school!(district, name \\ "Sandbox Middle", slug \\ "sm") do
    {:ok, s} =
      Ash.create(School, %{name: name, slug: slug, district_id: district.id},
        authorize?: false
      )

    s
  end

  def create_student!(school, attrs \\ %{}) do
    defaults = %{
      first_name: "Test",
      last_name: "Student#{System.unique_integer([:positive])}",
      grade_level: 9,
      enrollment_status: :active
    }

    Ash.create!(Student, Map.merge(defaults, attrs),
      tenant: school.id,
      authorize?: false
    )
  end

  def create_tag!(school, attrs \\ %{}) do
    defaults = %{name: "Tag#{System.unique_integer([:positive])}", color: "#2b4366"}

    Ash.create!(Tag, Map.merge(defaults, attrs),
      tenant: school.id,
      authorize?: false
    )
  end

  def create_status!(school, attrs \\ %{}) do
    defaults = %{
      name: "Status#{System.unique_integer([:positive])}",
      color: "#4b4b4d",
      position: 0
    }

    Ash.create!(Status, Map.merge(defaults, attrs),
      tenant: school.id,
      authorize?: false
    )
  end

  def apply_tag!(actor, school, student, tag) do
    Ash.create!(
      StudentTag,
      %{student_id: student.id, tag_id: tag.id},
      tenant: school.id,
      actor: actor,
      authorize?: false
    )
  end

  def create_custom_list!(actor, school, attrs \\ %{}) do
    defaults = %{
      name: "List#{System.unique_integer([:positive])}",
      filters: %{}
    }

    Ash.create!(
      CustomList,
      Map.merge(defaults, attrs),
      tenant: school.id,
      actor: actor,
      authorize?: false
    )
  end

  defp register!(email, password) do
    Ash.create!(
      User,
      %{email: email, password: password, password_confirmation: password},
      action: :register_with_password,
      authorize?: false
    )
  end

  defp attach_district!(user, district_id) do
    Ash.update!(user, %{district_id: district_id},
      action: :set_district,
      authorize?: false
    )
  end

  defp with_membership!(user, school_id, role) do
    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: user.id, school_id: school_id, role: role, source: :manual},
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end
end
