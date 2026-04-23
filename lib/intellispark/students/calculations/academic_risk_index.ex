defmodule Intellispark.Students.Calculations.AcademicRiskIndex do
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

      band_from(scores)
    end)
  end

  defp band_from([]), do: nil

  defp band_from(scores) do
    mean = Enum.sum(Enum.map(scores, & &1.score_value)) / length(scores)

    cond do
      mean >= 3.75 -> :low
      mean >= 2.5 -> :moderate
      mean >= 1.25 -> :high
      true -> :critical
    end
  end
end
