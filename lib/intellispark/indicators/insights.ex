defmodule Intellispark.Indicators.Insights do
  @moduledoc """
  Read-only query helpers for the Phase 9 Insights view. Two functions:
  `summary_for/3` returns `{low, moderate, high, unscored, total}` for a
  cohort + dimension; `individual_for/3` returns the per-student
  breakdown sorted by last+first name.
  """

  require Ash.Query

  alias Intellispark.Indicators.IndicatorScore
  alias Intellispark.Students.Student

  @spec summary_for([Ash.UUID.t()], atom(), Ash.UUID.t()) :: %{
          low: non_neg_integer(),
          moderate: non_neg_integer(),
          high: non_neg_integer(),
          unscored: non_neg_integer(),
          total: non_neg_integer()
        }
  def summary_for([], _dim, _school_id) do
    %{low: 0, moderate: 0, high: 0, unscored: 0, total: 0}
  end

  def summary_for(student_ids, dimension, school_id) when is_list(student_ids) do
    scores =
      IndicatorScore
      |> Ash.Query.filter(student_id in ^student_ids and dimension == ^dimension)
      |> Ash.Query.set_tenant(school_id)
      |> Ash.read!(authorize?: false)

    counts = Enum.frequencies_by(scores, & &1.level)
    scored_total = length(scores)

    %{
      low: Map.get(counts, :low, 0),
      moderate: Map.get(counts, :moderate, 0),
      high: Map.get(counts, :high, 0),
      unscored: length(student_ids) - scored_total,
      total: scored_total
    }
  end

  @spec individual_for([Ash.UUID.t()], atom(), Ash.UUID.t()) :: [
          %{id: Ash.UUID.t(), name: String.t(), level: atom() | nil}
        ]
  def individual_for([], _dim, _school_id), do: []

  def individual_for(student_ids, dimension, school_id) when is_list(student_ids) do
    Student
    |> Ash.Query.filter(id in ^student_ids)
    |> Ash.Query.set_tenant(school_id)
    |> Ash.Query.load([:display_name, dimension])
    |> Ash.Query.sort([:last_name, :first_name])
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn student ->
      %{
        id: student.id,
        name: student.display_name,
        level: Map.get(student, dimension)
      }
    end)
  end
end
