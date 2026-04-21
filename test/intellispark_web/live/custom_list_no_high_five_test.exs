defmodule IntellisparkWeb.CustomListNoHighFiveTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  alias Intellispark.Students

  setup do: setup_world()

  describe "no_high_five_in_30_days filter" do
    test "returns only students with 0 recent high 5s", %{school: school, admin: admin} do
      recipient = create_student!(school, %{first_name: "Gotta", last_name: "Mail"})
      no_mail = create_student!(school, %{first_name: "Solo", last_name: "Silence"})

      _ =
        send_high_five!(admin, school, recipient, %{
          title: "Nice",
          body: "Body",
          recipient_email: "r@example.com"
        })

      {:ok, list} =
        Students.create_custom_list(
          "No recent high 5s",
          %{no_high_five_in_30_days: true},
          actor: admin,
          tenant: school.id
        )

      {:ok, results} =
        Students.run_custom_list(list.id, actor: admin, tenant: school.id)

      ids = Enum.map(results, & &1.id)

      assert no_mail.id in ids
      refute recipient.id in ids
    end
  end
end
