defmodule Intellispark.Indicators.InsightsTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Indicators

  setup do
    %{school: school, admin: admin, district: district} = setup_world()

    students =
      for i <- 1..5 do
        create_student!(school, %{first_name: "S#{i}", last_name: "L#{i}"})
      end

    %{
      school: school,
      admin: admin,
      district: district,
      students: students
    }
  end

  describe "summary_for/3" do
    test "empty cohort returns all zeros without DB hit", %{school: school} do
      assert Indicators.summary_for([], :belonging, school.id) ==
               %{low: 0, moderate: 0, high: 0, unscored: 0, total: 0}
    end

    test "5 students with 3/1/1 level distribution", %{school: school, students: students} do
      [s1, s2, s3, s4, s5] = students

      {:ok, _} =
        Indicators.upsert_indicator_score(s1.id, :connection, :low, 1.5, 2, tenant: school.id)

      {:ok, _} =
        Indicators.upsert_indicator_score(s2.id, :connection, :low, 2.0, 2, tenant: school.id)

      {:ok, _} =
        Indicators.upsert_indicator_score(s3.id, :connection, :low, 1.0, 2, tenant: school.id)

      {:ok, _} =
        Indicators.upsert_indicator_score(s4.id, :connection, :moderate, 3.0, 2,
          tenant: school.id
        )

      {:ok, _} =
        Indicators.upsert_indicator_score(s5.id, :connection, :high, 4.5, 2, tenant: school.id)

      summary =
        Indicators.summary_for(Enum.map(students, & &1.id), :connection, school.id)

      assert summary == %{low: 3, moderate: 1, high: 1, unscored: 0, total: 5}
    end

    test "partial coverage — 5 students but only 2 scored",
         %{school: school, students: students} do
      [s1, s2, _, _, _] = students

      {:ok, _} =
        Indicators.upsert_indicator_score(s1.id, :engagement, :high, 4.5, 2, tenant: school.id)

      {:ok, _} =
        Indicators.upsert_indicator_score(s2.id, :engagement, :moderate, 3.0, 2,
          tenant: school.id
        )

      summary =
        Indicators.summary_for(Enum.map(students, & &1.id), :engagement, school.id)

      assert summary == %{low: 0, moderate: 1, high: 1, unscored: 3, total: 2}
    end
  end

  describe "individual_for/3" do
    test "empty cohort returns []", %{school: school} do
      assert Indicators.individual_for([], :belonging, school.id) == []
    end

    test "returns rows sorted by last+first name", %{school: school} do
      alice = create_student!(school, %{first_name: "Alice", last_name: "Zebra"})
      bob = create_student!(school, %{first_name: "Bob", last_name: "Alpha"})
      carol = create_student!(school, %{first_name: "Carol", last_name: "Alpha"})

      rows =
        Indicators.individual_for([alice.id, bob.id, carol.id], :belonging, school.id)

      assert Enum.map(rows, & &1.name) == ["Bob Alpha", "Carol Alpha", "Alice Zebra"]
    end

    test "unscored student returns level: nil", %{school: school, students: students} do
      [s1 | _] = students

      [row] = Indicators.individual_for([s1.id], :belonging, school.id)
      assert row.level == nil
      assert row.id == s1.id
    end
  end

  describe "cross-tenant" do
    test "student_ids from school B dropped when tenanted to school A",
         %{school: school, district: district} do
      school_b = add_second_school!(district, "Insights Other", "insights-other")
      other_student = create_student!(school_b)

      {:ok, _} =
        Indicators.upsert_indicator_score(other_student.id, :belonging, :high, 4.5, 2,
          tenant: school_b.id
        )

      summary = Indicators.summary_for([other_student.id], :belonging, school.id)
      assert summary == %{low: 0, moderate: 0, high: 0, unscored: 1, total: 0}

      rows = Indicators.individual_for([other_student.id], :belonging, school.id)
      assert rows == []
    end
  end
end
