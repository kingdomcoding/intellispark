defmodule Intellispark.Indicators.ScoringTest do
  use Intellispark.DataCase, async: false
  use ExUnitProperties

  import Intellispark.IndicatorsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments.{SurveyResponse, SurveyTemplateVersion}
  alias Intellispark.Indicators
  alias Intellispark.Indicators.{IndicatorScore, Scoring}

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

  describe "bucket/1" do
    test "at threshold boundaries" do
      assert Scoring.bucket(2.49) == :low
      assert Scoring.bucket(2.5) == :moderate
      assert Scoring.bucket(3.74) == :moderate
      assert Scoring.bucket(3.75) == :high
    end

    test "at extremes" do
      assert Scoring.bucket(1.0) == :low
      assert Scoring.bucket(5.0) == :high
      assert Scoring.bucket(3.0) == :moderate
    end
  end

  describe "score_responses/2" do
    test "one dimension fully answered produces one row with correct mean + level" do
      version = %SurveyTemplateVersion{
        schema: %{
          "questions" => [
            %{
              "id" => "q1",
              "question_type" => "dimension_rating",
              "metadata" => %{"dimension" => "belonging"}
            },
            %{
              "id" => "q2",
              "question_type" => "dimension_rating",
              "metadata" => %{"dimension" => "belonging"}
            }
          ]
        }
      }

      responses = [
        %SurveyResponse{question_id: "q1", answer_text: "5"},
        %SurveyResponse{question_id: "q2", answer_text: "4"}
      ]

      [row] = Scoring.score_responses(version, responses)
      assert row.dimension == :belonging
      assert row.score_value == 4.5
      assert row.level == :high
      assert row.answered_count == 2
    end

    test "one dimension zero-answered produces no row" do
      version = %SurveyTemplateVersion{
        schema: %{
          "questions" => [
            %{
              "id" => "q1",
              "question_type" => "dimension_rating",
              "metadata" => %{"dimension" => "belonging"}
            }
          ]
        }
      }

      assert Scoring.score_responses(version, []) == []
    end

    test "mixed-coverage template produces rows only for answered dimensions" do
      version = %SurveyTemplateVersion{
        schema: %{
          "questions" => [
            %{
              "id" => "q1",
              "question_type" => "dimension_rating",
              "metadata" => %{"dimension" => "belonging"}
            },
            %{
              "id" => "q2",
              "question_type" => "dimension_rating",
              "metadata" => %{"dimension" => "connection"}
            },
            %{
              "id" => "q3",
              "question_type" => "dimension_rating",
              "metadata" => %{"dimension" => "engagement"}
            }
          ]
        }
      }

      responses = [
        %SurveyResponse{question_id: "q1", answer_text: "2"},
        %SurveyResponse{question_id: "q3", answer_text: "5"}
      ]

      rows = Scoring.score_responses(version, responses)
      assert length(rows) == 2

      dims = Enum.map(rows, & &1.dimension) |> Enum.sort()
      assert dims == [:belonging, :engagement]
    end
  end

  describe "compute_for_assignment/2" do
    test "idempotence — running twice produces identical IndicatorScore rows",
         %{school: school, admin: admin, student: student} do
      template = insightfull_template!(school, admin)
      assignment = submit_all!(admin, school, student, template, 4)

      :ok = Indicators.compute_for_assignment(assignment.id, school.id)

      rows_after_first =
        IndicatorScore
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      :ok = Indicators.compute_for_assignment(assignment.id, school.id)

      rows_after_second =
        IndicatorScore
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(rows_after_first) == length(rows_after_second)
      assert length(rows_after_first) == 13

      assert rows_after_first |> Enum.map(& &1.id) |> Enum.sort() ==
               rows_after_second |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "on unknown assignment returns {:error, :assignment_not_found}",
         %{school: school} do
      assert {:error, :assignment_not_found} =
               Indicators.compute_for_assignment(Ecto.UUID.generate(), school.id)
    end

    test "preserves paper-trail history across reruns",
         %{school: school, admin: admin, student: student} do
      template = insightfull_template!(school, admin)
      assignment = submit_all!(admin, school, student, template, 4)

      :ok = Indicators.compute_for_assignment(assignment.id, school.id)
      :ok = Indicators.compute_for_assignment(assignment.id, school.id)

      versions =
        IndicatorScore.Version
        |> Ash.Query.filter(dimension == :belonging and student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(versions) == 2
    end

    test "broadcasts {:indicator_scores_updated, student_id}",
         %{school: school, admin: admin, student: student} do
      Phoenix.PubSub.subscribe(Intellispark.PubSub, "indicator_scores:student:#{student.id}")

      template = insightfull_template!(school, admin)
      assignment = submit_all!(admin, school, student, template, 4)

      :ok = Indicators.compute_for_assignment(assignment.id, school.id)

      assert_receive {:indicator_scores_updated, student_id}, 1_000
      assert student_id == student.id
    end
  end

  describe "properties" do
    property "bucket monotonicity" do
      level_order = fn
        :low -> 0
        :moderate -> 1
        :high -> 2
      end

      check all a <- float(min: 1.0, max: 5.0),
                b <- float(min: 1.0, max: 5.0) do
        [lo, hi] = Enum.sort([a, b])
        assert level_order.(Scoring.bucket(lo)) <= level_order.(Scoring.bucket(hi))
      end
    end

    property "full-coverage invariant", %{
      school: school,
      admin: admin,
      student: student
    } do
      template = insightfull_template!(school, admin, items_per_dimension: 1)

      check all n <- integer(1..5), max_runs: 5 do
        assignment = submit_all!(admin, school, student, template, n)
        :ok = Indicators.compute_for_assignment(assignment.id, school.id)

        scores =
          IndicatorScore
          |> Ash.Query.filter(student_id == ^student.id)
          |> Ash.Query.set_tenant(school.id)
          |> Ash.read!(authorize?: false)

        expected = Scoring.bucket(n * 1.0)

        for s <- scores do
          assert s.level == expected,
                 "expected #{inspect(expected)} for #{n}, got #{inspect(s.level)} on #{s.dimension}"
        end
      end
    end
  end
end
