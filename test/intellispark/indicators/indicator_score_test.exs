defmodule Intellispark.Indicators.IndicatorScoreTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Indicators
  alias Intellispark.Indicators.IndicatorScore

  setup do
    %{school: school, admin: admin, district: district} = setup_world()
    student = create_student!(school)

    %{
      school: school,
      admin: admin,
      district: district,
      student: student
    }
  end

  describe "upsert identity" do
    test "two creates with same (student_id, dimension) produce one row; second wins",
         %{school: school, student: student} do
      {:ok, row1} =
        Indicators.upsert_indicator_score(student.id, :belonging, :low, 2.0, 2, tenant: school.id)

      {:ok, row2} =
        Indicators.upsert_indicator_score(student.id, :belonging, :high, 4.5, 2,
          tenant: school.id
        )

      assert row1.id == row2.id
      assert row2.level == :high

      rows =
        IndicatorScore
        |> Ash.Query.filter(student_id == ^student.id and dimension == :belonging)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(rows) == 1
    end
  end

  describe "paper trail" do
    test "writes Version rows on create + update",
         %{school: school, student: student} do
      {:ok, row} =
        Indicators.upsert_indicator_score(student.id, :engagement, :low, 1.5, 2,
          tenant: school.id
        )

      {:ok, _} =
        Indicators.upsert_indicator_score(student.id, :engagement, :high, 4.0, 2,
          tenant: school.id
        )

      versions =
        IndicatorScore.Version
        |> Ash.Query.filter(version_source_id == ^row.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(versions) == 2
    end
  end

  describe "tenant isolation" do
    test "rows in school A invisible from school B",
         %{school: school, district: district, student: student} do
      other_school = add_second_school!(district, "Other Ind", "other-ind")

      {:ok, _} =
        Indicators.upsert_indicator_score(student.id, :belonging, :low, 2.0, 2, tenant: school.id)

      rows =
        IndicatorScore
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(other_school.id)
        |> Ash.read!(authorize?: false)

      assert rows == []
    end
  end

  describe ":for_student action" do
    test "returns only the specified student's scores",
         %{school: school, student: student} do
      other = create_student!(school)

      {:ok, _} =
        Indicators.upsert_indicator_score(student.id, :belonging, :low, 2.0, 2, tenant: school.id)

      {:ok, _} =
        Indicators.upsert_indicator_score(other.id, :belonging, :high, 4.5, 2, tenant: school.id)

      scores =
        Indicators.indicator_scores_for_student!(student.id,
          tenant: school.id,
          authorize?: false
        )

      assert Enum.all?(scores, &(&1.student_id == student.id))
      assert length(scores) == 1
    end
  end

  describe "policy gate" do
    test "admin in same school can read",
         %{school: school, admin: admin, student: student} do
      admin_loaded = Ash.load!(admin, [school_memberships: [:school]], authorize?: false)

      {:ok, _} =
        Indicators.upsert_indicator_score(student.id, :belonging, :low, 2.0, 2, tenant: school.id)

      assert {:ok, [_row]} =
               IndicatorScore
               |> Ash.Query.filter(student_id == ^student.id)
               |> Ash.Query.set_tenant(school.id)
               |> Ash.read(actor: admin_loaded)
    end
  end
end
