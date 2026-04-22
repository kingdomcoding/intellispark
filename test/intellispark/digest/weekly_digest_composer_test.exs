defmodule Intellispark.Digest.WeeklyDigestComposerTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures
  import Intellispark.RecognitionFixtures
  import Intellispark.FlagsFixtures

  alias Intellispark.Digest.WeeklyDigestComposer
  alias Intellispark.Digest.WeeklyDigestComposer.Digest

  setup do: setup_world()

  test "empty cohort → empty digest", %{school: school, admin: admin} do
    digest = WeeklyDigestComposer.build(admin, school.id, Date.utc_today() |> Date.add(-7))

    assert WeeklyDigestComposer.empty?(digest)
    assert digest.sections == []
  end

  test "cohort with no recent activity → empty digest", %{school: school, admin: admin} do
    student = create_student!(school)
    _ = create_team_membership!(admin, school, student, admin, :counselor)

    digest = WeeklyDigestComposer.build(admin, school.id, Date.utc_today() |> Date.add(-7))

    assert WeeklyDigestComposer.empty?(digest)
  end

  test "cohort with a high-five → digest with high_fives section",
       %{school: school, admin: admin} do
    student = create_student!(school)
    _ = create_team_membership!(admin, school, student, admin, :counselor)

    _ =
      send_high_five!(admin, school, student, %{
        title: "Great work",
        body: "You did great",
        recipient_email: "kid@example.com"
      })

    digest = WeeklyDigestComposer.build(admin, school.id, Date.utc_today() |> Date.add(-7))

    refute WeeklyDigestComposer.empty?(digest)
    assert {:high_fives, items} = List.keyfind(digest.sections, :high_fives, 0)
    assert length(items) == 1
  end

  test "flag annotation: assigned_to_recipient? true when assignment matches user",
       %{school: school, admin: admin} do
    student = create_student!(school)
    _ = create_team_membership!(admin, school, student, admin, :counselor)
    type = create_flag_type!(school)
    flag = create_flag!(admin, school, student, type)
    _ = open_flag!(flag, [admin.id], admin)

    digest = WeeklyDigestComposer.build(admin, school.id, Date.utc_today() |> Date.add(-7))

    assert {:flags, items} = List.keyfind(digest.sections, :flags, 0)
    assert [annotated] = items
    assert annotated.assigned_to_recipient? == true
  end

  test "empty?/1 returns true on empty Digest" do
    assert WeeklyDigestComposer.empty?(%Digest{sections: []})
  end

  test "empty?/1 returns false on populated Digest" do
    refute WeeklyDigestComposer.empty?(%Digest{sections: [{:high_fives, [%{}]}]})
  end
end
