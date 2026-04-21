defmodule Intellispark.Recognition.PoliciesTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  alias Intellispark.Accounts.{User, UserSchoolMembership}
  alias Intellispark.Recognition
  alias Intellispark.Recognition.HighFive

  setup do: setup_world()

  defp user_with_role!(school, role) do
    user =
      Ash.create!(
        User,
        %{
          email: "#{role}-#{System.unique_integer([:positive])}@sandbox.edu",
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

  describe "CanSendHighFive" do
    test "teacher on school A can send to student in school A", %{
      school: school,
      admin: _admin
    } do
      teacher = user_with_role!(school, :teacher)
      student = create_student!(school, %{email: "s@example.com"})

      {:ok, _} =
        HighFive
        |> Ash.Changeset.for_create(
          :send_to_student,
          %{
            student_id: student.id,
            title: "T",
            body: "B",
            recipient_email: "s@example.com"
          },
          actor: teacher,
          tenant: school.id
        )
        |> Ash.create()
    end

    test "teacher on school A cannot send to student in school B", %{
      district: district,
      school: school,
      admin: _admin
    } do
      other_school = add_second_school!(district)
      teacher = user_with_role!(school, :teacher)
      student_b = create_student!(other_school, %{email: "b@example.com"})

      assert {:error, _} =
               HighFive
               |> Ash.Changeset.for_create(
                 :send_to_student,
                 %{
                   student_id: student_b.id,
                   title: "T",
                   body: "B",
                   recipient_email: "b@example.com"
                 },
                 actor: teacher,
                 tenant: other_school.id
               )
               |> Ash.create()
    end

    test "counselor can send", %{school: school} do
      counselor = user_with_role!(school, :counselor)
      student = create_student!(school, %{email: "c@example.com"})

      {:ok, _} =
        HighFive
        |> Ash.Changeset.for_create(
          :send_to_student,
          %{
            student_id: student.id,
            title: "T",
            body: "B",
            recipient_email: "c@example.com"
          },
          actor: counselor,
          tenant: school.id
        )
        |> Ash.create()
    end

    test "stranger with no memberships cannot send", %{school: school} do
      stranger =
        Ash.create!(
          User,
          %{
            email: "stranger-#{System.unique_integer([:positive])}@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )
        |> Ash.load!([:school_memberships], authorize?: false)

      student = create_student!(school, %{email: "x@example.com"})

      assert {:error, _} =
               HighFive
               |> Ash.Changeset.for_create(
                 :send_to_student,
                 %{
                   student_id: student.id,
                   title: "T",
                   body: "B",
                   recipient_email: "x@example.com"
                 },
                 actor: stranger,
                 tenant: school.id
               )
               |> Ash.create()
    end
  end

  describe "public actions" do
    test "unauthenticated :by_token succeeds", %{school: school, admin: admin} do
      student = create_student!(school)

      hf =
        send_high_five!(admin, school, student, %{recipient_email: "r@example.com"})

      {:ok, found} =
        Recognition.get_high_five_by_token(hf.token, authorize?: false)

      assert found.id == hf.id
    end

    test "unauthenticated :record_view succeeds", %{school: school, admin: admin} do
      student = create_student!(school)

      hf =
        send_high_five!(admin, school, student, %{recipient_email: "r@example.com"})

      {:ok, updated} =
        Recognition.record_high_five_view(hf, "ua", nil,
          tenant: school.id,
          authorize?: false
        )

      assert updated.view_count == 1
    end
  end
end
