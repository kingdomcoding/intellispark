defmodule Mix.Tasks.Indicators.RecomputeTest do
  use Intellispark.DataCase, async: false

  import Intellispark.IndicatorsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Indicators.IndicatorScore

  setup do
    %{school: school, admin: admin, district: district} = setup_world()
    other_school = add_second_school!(district, "Recompute Other", "recompute-other")

    admin_other =
      Ash.create!(
        Intellispark.Accounts.UserSchoolMembership,
        %{user_id: admin.id, school_id: other_school.id, role: :admin, source: :manual},
        authorize?: false
      )

    _ = admin_other

    {:ok, refreshed} =
      Ash.update(admin, %{district_id: district.id},
        action: :set_district,
        authorize?: false
      )

    admin = Ash.load!(refreshed, [school_memberships: [:school]], authorize?: false)

    student_a = create_student!(school, %{first_name: "A"})
    student_b = create_student!(school, %{first_name: "B"})
    student_c = create_student!(other_school, %{first_name: "C"})

    template_a = insightfull_template!(school, admin)
    template_b = insightfull_template!(other_school, admin)

    _ = submit_all!(admin, school, student_a, template_a, 5)
    _ = submit_all!(admin, school, student_b, template_a, 2)
    _ = submit_all!(admin, other_school, student_c, template_b, 3)

    %{
      school: school,
      other_school: other_school,
      admin: admin,
      student_a: student_a,
      student_b: student_b,
      student_c: student_c
    }
  end

  describe "mix indicators.recompute" do
    test "walks all schools' submitted assignments + produces 13 rows per student",
         %{school: school, other_school: other_school} do
      Mix.Tasks.Indicators.Recompute.run([])

      school_rows =
        IndicatorScore
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      other_rows =
        IndicatorScore
        |> Ash.Query.set_tenant(other_school.id)
        |> Ash.read!(authorize?: false)

      # 2 students × 13 in main school + 1 × 13 in other = 39
      assert length(school_rows) + length(other_rows) == 39
    end

    test "idempotent — second run produces same row count",
         %{school: school} do
      Mix.Tasks.Indicators.Recompute.run([])

      first =
        IndicatorScore
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      first_version_count =
        IndicatorScore.Version
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)
        |> length()

      Mix.Tasks.Indicators.Recompute.run([])

      second =
        IndicatorScore
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(second) == length(first)

      second_version_count =
        IndicatorScore.Version
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)
        |> length()

      assert second_version_count >= first_version_count * 2 - 1
    end
  end
end
