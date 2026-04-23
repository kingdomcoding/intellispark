defmodule Intellispark.Students.Calculations.ContributingFactors do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Intellispark.Assessments.Resiliency.SkillScore

  require Ash.Query

  @skills ~w(confidence persistence organization getting_along resilience curiosity)a

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def load(_query, _opts, _context), do: [:school_id]

  @impl true
  def calculate(students, _opts, _context) do
    Enum.map(students, fn student ->
      scores =
        SkillScore
        |> Ash.Query.filter(student_id == ^student.id and skill in ^@skills)
        |> Ash.Query.set_tenant(student.school_id)
        |> Ash.read!(authorize?: false)

      factors_from(scores)
    end)
  end

  defp factors_from([]), do: []

  defp factors_from(scores) do
    mean = Enum.sum(Enum.map(scores, & &1.score_value)) / length(scores)

    if mean >= 3.75 do
      []
    else
      scores
      |> Enum.reject(&(&1.level == :high))
      |> Enum.sort_by(fn s -> {s.score_value, to_string(s.skill)} end)
      |> Enum.take(2)
      |> Enum.map(& &1.skill)
    end
  end
end
