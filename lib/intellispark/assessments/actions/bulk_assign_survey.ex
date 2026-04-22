defmodule Intellispark.Assessments.Actions.BulkAssignSurvey do
  @moduledoc """
  Generic action implementing `SurveyAssignment.:bulk_assign_to_students`.
  Two modes matching the real-product modal:
  - `:skip_if_previously_assigned` filters out students who already have
    any assignment for this template, regardless of state (assigned,
    in_progress, submitted, or expired). Matches the "Assign only if
    never assigned" button.
  - `:assign_regardless` creates one assignment per student unconditionally.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Intellispark.Assessments.{SurveyAssignment, SurveyTemplate}

  @impl true
  def run(input, _opts, context) do
    student_ids = input.arguments.student_ids
    template_id = input.arguments.survey_template_id
    mode = input.arguments.mode
    tenant = context.tenant
    actor = context.actor

    with {:ok, _template} <-
           Ash.get(SurveyTemplate, template_id,
             tenant: tenant,
             actor: actor,
             authorize?: true
           ) do
      effective_ids = filter_students(mode, student_ids, template_id, tenant)

      payloads =
        Enum.map(effective_ids, fn sid ->
          %{student_id: sid, survey_template_id: template_id}
        end)

      result =
        Ash.bulk_create(
          payloads,
          SurveyAssignment,
          :assign_to_student,
          actor: actor,
          tenant: tenant,
          return_records?: true,
          return_errors?: true,
          stop_on_error?: false,
          notify?: true,
          return_notifications?: false
        )

      {:ok, result}
    end
  end

  defp filter_students(:assign_regardless, student_ids, _template_id, _tenant), do: student_ids

  defp filter_students(:skip_if_previously_assigned, student_ids, template_id, tenant) do
    already_assigned =
      SurveyAssignment
      |> Ash.Query.filter(
        survey_template_id == ^template_id and
          student_id in ^student_ids
      )
      |> Ash.Query.set_tenant(tenant)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.student_id)

    student_ids -- already_assigned
  end
end
