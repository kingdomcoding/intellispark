defmodule Mix.Tasks.Indicators.Recompute do
  @moduledoc """
  Recomputes every IndicatorScore row from every submitted Insightfull
  SurveyAssignment. Idempotent: re-running produces the same rows
  because upsert_identity covers (student_id, dimension).

  Usage:

      mix indicators.recompute                # all schools
      mix indicators.recompute --school <id>  # one tenant

  The task walks submitted assignments in chronological order so the
  latest submission wins the upsert.
  """

  use Mix.Task

  require Ash.Query

  alias Intellispark.Assessments.SurveyAssignment

  @shortdoc "Recompute all SEL indicator scores from submitted surveys"

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(argv, strict: [school: :string])
    schools = list_schools(opts[:school])

    for school <- schools do
      IO.puts("Recomputing indicators for school #{school.id}…")
      recompute_school(school)
    end
  end

  defp list_schools(nil) do
    Intellispark.Accounts.School |> Ash.read!(authorize?: false)
  end

  defp list_schools(id) do
    [Ash.get!(Intellispark.Accounts.School, id, authorize?: false)]
  end

  defp recompute_school(school) do
    assignments =
      SurveyAssignment
      |> Ash.Query.filter(state == :submitted)
      |> Ash.Query.sort(submitted_at: :asc)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    for a <- assignments do
      case Intellispark.Indicators.compute_for_assignment(a.id, a.school_id) do
        :ok ->
          IO.write(".")

        {:error, reason} ->
          IO.puts("\n  assignment #{a.id} failed: #{inspect(reason)}")
      end
    end

    IO.puts("")
  end
end
