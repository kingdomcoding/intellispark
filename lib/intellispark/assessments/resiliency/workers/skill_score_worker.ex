defmodule Intellispark.Assessments.Resiliency.Workers.SkillScoreWorker do
  @moduledoc """
  Triggered by `ResiliencyAssessment.:submit` via an after_action. Reads
  the submitted assessment's responses, groups by skill via QuestionBank,
  upserts one SkillScore row per skill. Idempotent via the
  `:unique_per_student_skill` identity on SkillScore.
  """

  use Oban.Worker, queue: :indicators, max_attempts: 3

  require Ash.Query

  alias Intellispark.Assessments.Resiliency.{Assessment, QuestionBank, SkillScore}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"assessment_id" => id, "tenant" => tenant}}) do
    assessment =
      Assessment
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.load([:responses])
      |> Ash.Query.filter(id == ^id)
      |> Ash.read_one!(authorize?: false)

    if assessment == nil do
      :ok
    else
      score(assessment, tenant)
    end
  end

  defp score(assessment, tenant) do
    question_skill_map =
      assessment.grade_band
      |> QuestionBank.questions_for(assessment.version)
      |> Map.new(&{&1.id, &1.skill})

    grouped =
      assessment.responses
      |> Enum.group_by(&Map.get(question_skill_map, &1.question_id))
      |> Map.delete(nil)

    Enum.each(grouped, fn {skill, responses} ->
      answered_count = length(responses)
      sum = Enum.reduce(responses, 0, fn r, acc -> acc + r.value end)
      mean = sum / answered_count
      level = band_from(mean)

      Ash.create!(
        SkillScore,
        %{
          student_id: assessment.student_id,
          skill: skill,
          score_value: mean,
          level: level,
          answered_count: answered_count,
          assessment_id: assessment.id
        },
        action: :upsert,
        tenant: tenant,
        authorize?: false
      )
    end)

    :ok
  end

  defp band_from(mean) when mean >= 3.75, do: :high
  defp band_from(mean) when mean >= 2.5, do: :moderate
  defp band_from(_), do: :low
end
