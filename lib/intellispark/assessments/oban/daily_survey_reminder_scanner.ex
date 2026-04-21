defmodule Intellispark.Assessments.Oban.DailySurveyReminderScanner do
  @moduledoc """
  Daily cron that scans tenants for `:assigned` / `:in_progress`
  survey assignments that are at least 2 days old and haven't had a
  reminder in the last 4 days. Enqueues one
  `DeliverSurveyReminderWorker` job per due assignment.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Ash.Query

  alias Intellispark.Assessments.Oban.DeliverSurveyReminderWorker
  alias Intellispark.Assessments.SurveyAssignment

  @reminder_threshold_seconds 2 * 86_400
  @cooldown_seconds 4 * 86_400

  @impl Oban.Worker
  def perform(_job) do
    schools = Intellispark.Accounts.School |> Ash.read!(authorize?: false)
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -@reminder_threshold_seconds, :second)

    for school <- schools do
      assignments =
        SurveyAssignment
        |> Ash.Query.filter(
          state in [:assigned, :in_progress] and
            assigned_at <= ^cutoff
        )
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      for a <- assignments, due_for_reminder?(a, now) do
        %{assignment_id: a.id, school_id: a.school_id}
        |> DeliverSurveyReminderWorker.new()
        |> Oban.insert()
      end
    end

    :ok
  end

  defp due_for_reminder?(%{last_reminded_at: nil}, _now), do: true

  defp due_for_reminder?(%{last_reminded_at: ts}, now) do
    DateTime.diff(now, ts, :second) >= @cooldown_seconds
  end
end
