defmodule Intellispark.Students.Calculations.IndicatorLevel do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Intellispark.Indicators.IndicatorScore

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(students, opts, _context) do
    dim = opts[:dimension]

    Enum.map(students, fn student ->
      IndicatorScore
      |> Ash.Query.filter(student_id == ^student.id and dimension == ^dim)
      |> Ash.Query.sort(last_computed_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.Query.set_tenant(student.school_id)
      |> Ash.read!(authorize?: false)
      |> case do
        [%IndicatorScore{level: l}] -> l
        _ -> nil
      end
    end)
  end
end
