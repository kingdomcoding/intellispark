defmodule Intellispark.Indicators.Scoring do
  @moduledoc """
  Pure scoring logic for Insightfull responses. Deterministic +
  idempotent — `compute_for_assignment/1` run twice produces the same
  upsert result. Thresholds are module attributes so property-based
  tests can re-verify monotonicity.
  """

  require Ash.Query

  alias Intellispark.Assessments.{SurveyAssignment, SurveyResponse, SurveyTemplateVersion}
  alias Intellispark.Indicators.{Dimension, IndicatorScore}

  @low_threshold 2.5
  @high_threshold 3.75

  @spec compute_for_assignment(Ash.UUID.t(), Ash.UUID.t() | nil) :: :ok | {:error, term()}
  def compute_for_assignment(assignment_id, school_id \\ nil) do
    with {:ok, assignment} <- load_assignment(assignment_id, school_id),
         {:ok, version} <- load_version(assignment),
         {:ok, responses} <- load_responses(assignment) do
      scores = score_responses(version, responses)
      upsert_all(scores, assignment)
      broadcast(assignment.student_id)
      :ok
    end
  end

  @spec score_responses(SurveyTemplateVersion.t(), [SurveyResponse.t()]) :: [map()]
  def score_responses(%SurveyTemplateVersion{schema: schema}, responses) do
    response_by_qid = Map.new(responses, fn r -> {r.question_id, r} end)

    (schema["questions"] || [])
    |> Enum.filter(fn q -> q["question_type"] == "dimension_rating" end)
    |> Enum.group_by(fn q -> q["metadata"]["dimension"] end)
    |> Enum.flat_map(fn {dim_string, questions} ->
      case Dimension.from_string(dim_string || "") do
        :error -> []
        {:ok, dim} -> score_dimension(dim, questions, response_by_qid)
      end
    end)
  end

  @spec bucket(float() | integer()) :: :low | :moderate | :high
  def bucket(score) when is_float(score) or is_integer(score) do
    cond do
      score < @low_threshold -> :low
      score < @high_threshold -> :moderate
      true -> :high
    end
  end

  defp score_dimension(dimension, questions, response_by_qid) do
    numeric_answers =
      questions
      |> Enum.map(fn q -> response_by_qid[q["id"]] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&parse_likert_int/1)
      |> Enum.reject(&is_nil/1)

    case numeric_answers do
      [] ->
        []

      vs ->
        mean = Enum.sum(vs) / length(vs)

        [
          %{
            dimension: dimension,
            level: bucket(mean),
            score_value: mean,
            answered_count: length(vs)
          }
        ]
    end
  end

  defp parse_likert_int(%SurveyResponse{answer_text: t}) when is_binary(t) do
    case Integer.parse(t) do
      {n, ""} when n in 1..5 -> n
      _ -> nil
    end
  end

  defp parse_likert_int(_), do: nil

  defp load_assignment(id, school_id) when is_binary(school_id) do
    case Ash.get(SurveyAssignment, id, tenant: school_id, authorize?: false) do
      {:ok, a} ->
        {:ok, a}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        {:error, :assignment_not_found}

      err ->
        err
    end
  end

  defp load_assignment(id, nil) do
    Intellispark.Accounts.School
    |> Ash.read!(authorize?: false)
    |> Enum.find_value({:error, :assignment_not_found}, fn school ->
      case Ash.get(SurveyAssignment, id, tenant: school.id, authorize?: false) do
        {:ok, a} -> {:ok, a}
        _ -> false
      end
    end)
  end

  defp load_version(%SurveyAssignment{survey_template_version_id: vid, school_id: school_id}) do
    case Ash.get(SurveyTemplateVersion, vid, tenant: school_id, authorize?: false) do
      {:ok, v} -> {:ok, v}
      err -> err
    end
  end

  defp load_responses(%SurveyAssignment{id: id, school_id: school_id}) do
    {:ok,
     SurveyResponse
     |> Ash.Query.filter(survey_assignment_id == ^id)
     |> Ash.Query.set_tenant(school_id)
     |> Ash.read!(authorize?: false)}
  end

  defp upsert_all(scores, assignment) do
    Enum.each(scores, fn %{
                           dimension: d,
                           level: l,
                           score_value: v,
                           answered_count: n
                         } ->
      Ash.create!(
        IndicatorScore,
        %{
          student_id: assignment.student_id,
          source_survey_assignment_id: assignment.id,
          dimension: d,
          level: l,
          score_value: v,
          answered_count: n,
          last_computed_at: DateTime.utc_now()
        },
        tenant: assignment.school_id,
        upsert?: true,
        upsert_identity: :unique_per_student_dimension,
        authorize?: false
      )
    end)
  end

  defp broadcast(student_id) do
    Phoenix.PubSub.broadcast(
      Intellispark.PubSub,
      "indicator_scores:student:#{student_id}",
      {:indicator_scores_updated, student_id}
    )
  end
end
