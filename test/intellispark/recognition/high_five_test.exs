defmodule Intellispark.Recognition.HighFiveTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  require Ash.Query

  alias Intellispark.Recognition
  alias Intellispark.Recognition.{HighFive, HighFiveView}

  setup do: setup_world()

  describe ":send_to_student" do
    test "stamps sent_by + generates a 22-character token", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)

      hf =
        send_high_five!(admin, school, student, %{
          title: "Great work",
          body: "You did it!",
          recipient_email: "student@example.com"
        })

      assert hf.sent_by_id == admin.id
      assert hf.recipient_email == "student@example.com"
      assert String.length(hf.token) == 22
    end

    test "tokens are unique across sends", %{school: school, admin: admin} do
      student = create_student!(school)

      tokens =
        for _ <- 1..50 do
          send_high_five!(admin, school, student, %{
            title: "t#{System.unique_integer([:positive])}",
            body: "b",
            recipient_email: "x@example.com"
          }).token
        end

      assert length(Enum.uniq(tokens)) == 50
    end

    test "recipient_email override takes precedence over student.email", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{email: "sis@example.com"})

      hf =
        send_high_five!(admin, school, student, %{
          recipient_email: "override@example.com"
        })

      assert hf.recipient_email == "override@example.com"
    end

    test "falls back to student.email when no override given", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{email: "sis@example.com"})

      hf =
        HighFive
        |> Ash.Changeset.for_create(
          :send_to_student,
          %{
            student_id: student.id,
            title: "T",
            body: "B"
          },
          tenant: school.id,
          actor: admin
        )
        |> Ash.create!(authorize?: false)

      assert hf.recipient_email == "sis@example.com"
    end

    test "errors when neither override nor student.email exist", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)

      assert {:error, _} =
               HighFive
               |> Ash.Changeset.for_create(
                 :send_to_student,
                 %{
                   student_id: student.id,
                   title: "T",
                   body: "B"
                 },
                 tenant: school.id,
                 actor: admin
               )
               |> Ash.create(authorize?: false)
    end
  end

  describe ":by_token" do
    test "returns the high five cross-tenant", %{school: school, admin: admin} do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      {:ok, found} = Recognition.get_high_five_by_token(hf.token, authorize?: false)
      assert found.id == hf.id
    end

    test "returns NotFound error for an unknown token" do
      assert {:error, _} =
               Recognition.get_high_five_by_token("no-such-token", authorize?: false)
    end
  end

  describe ":record_view" do
    test "increments view_count + sets first_viewed_at + writes audit row", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      assert hf.view_count == 0
      assert hf.first_viewed_at == nil

      updated = record_view!(hf)

      assert updated.view_count == 1
      assert updated.first_viewed_at != nil

      audit =
        HighFiveView
        |> Ash.Query.filter(high_five_id == ^hf.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(audit) == 1
    end

    test "first_viewed_at is preserved across subsequent views", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      first = record_view!(hf)

      second =
        Ash.get!(HighFive, hf.id, tenant: school.id, authorize?: false)
        |> record_view!()

      assert first.first_viewed_at == second.first_viewed_at
      assert second.view_count == 2
    end
  end

  describe "paper trail" do
    test "writes a Version row on :send_to_student", %{school: school, admin: admin} do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      versions =
        HighFive.Version
        |> Ash.Query.filter(version_source_id == ^hf.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      names = Enum.map(versions, & &1.version_action_name)
      assert :send_to_student in names
    end
  end

  describe ":destroy" do
    test "authorize?: false destroys directly", %{school: school, admin: admin} do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      assert :ok =
               Recognition.archive_high_five(hf,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end
end
