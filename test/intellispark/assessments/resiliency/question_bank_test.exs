defmodule Intellispark.Assessments.Resiliency.QuestionBankTest do
  use ExUnit.Case, async: true

  alias Intellispark.Assessments.Resiliency.QuestionBank

  describe "questions_for/2" do
    test "each grade band returns exactly 18 questions" do
      assert 18 == length(QuestionBank.questions_for(:grades_9_12))
      assert 18 == length(QuestionBank.questions_for(:grades_6_8))
      assert 18 == length(QuestionBank.questions_for(:grades_3_5))
    end

    test "each grade band has exactly 3 questions per skill" do
      for band <- QuestionBank.grade_bands() do
        by_skill = Enum.group_by(QuestionBank.questions_for(band), & &1.skill)

        for skill <- QuestionBank.skills() do
          assert length(Map.get(by_skill, skill, [])) == 3,
                 "band #{band} skill #{skill} has #{length(Map.get(by_skill, skill, []))}"
        end
      end
    end
  end

  describe "skills/0" do
    test "returns the 6 canonical atoms in stable order" do
      assert QuestionBank.skills() ==
               [:confidence, :persistence, :organization, :getting_along, :resilience, :curiosity]
    end
  end
end
