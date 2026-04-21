defmodule Intellispark.Recognition.HighFiveViewTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  require Ash.Query

  alias Intellispark.Recognition.HighFiveView

  setup do: setup_world()

  describe "audit trail" do
    test "record_view writes a row with ua + ip_hash", %{school: school, admin: admin} do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      _ = record_view!(hf, %{user_agent: "chrome/123", ip_hash: "sha:abc"})

      [row] =
        HighFiveView
        |> Ash.Query.filter(high_five_id == ^hf.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert row.user_agent == "chrome/123"
      assert row.ip_hash == "sha:abc"
    end

    test "two views write two audit rows", %{school: school, admin: admin} do
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})

      _ = record_view!(hf)

      fresh =
        Ash.get!(Intellispark.Recognition.HighFive, hf.id, tenant: school.id, authorize?: false)

      _ = record_view!(fresh)

      count =
        HighFiveView
        |> Ash.Query.filter(high_five_id == ^hf.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.count!(authorize?: false)

      assert count == 2
    end

    test "tenant isolation", %{district: district, school: school, admin: admin} do
      other_school = add_second_school!(district)
      student = create_student!(school)
      hf = send_high_five!(admin, school, student, %{recipient_email: "x@example.com"})
      _ = record_view!(hf)

      rows =
        HighFiveView
        |> Ash.Query.set_tenant(other_school.id)
        |> Ash.read!(authorize?: false)

      assert rows == []
    end
  end
end
