defmodule Intellispark.Recognition.Actions.BulkSendHighFives do
  @moduledoc """
  Generic action implementing `HighFive.:bulk_send_to_students`. Looks
  up the given template once, then runs `Ash.bulk_create` over the
  student_ids list with `:send_to_student`. Returns the raw
  `%Ash.BulkResult{}` so callers can report partial failures.
  """

  use Ash.Resource.Actions.Implementation

  alias Intellispark.Recognition.HighFive
  alias Intellispark.Recognition.HighFiveTemplate

  @impl true
  def run(input, _opts, context) do
    student_ids = input.arguments.student_ids
    template_id = input.arguments.template_id
    tenant = context.tenant
    actor = context.actor

    with {:ok, template} <-
           Ash.get(HighFiveTemplate, template_id,
             tenant: tenant,
             actor: actor,
             authorize?: true
           ) do
      payloads =
        Enum.map(student_ids, fn student_id ->
          %{
            student_id: student_id,
            title: template.title,
            body: template.body,
            template_id: template.id
          }
        end)

      result =
        Ash.bulk_create(
          payloads,
          HighFive,
          :send_to_student,
          actor: actor,
          tenant: tenant,
          return_records?: true,
          return_errors?: true,
          stop_on_error?: false
        )

      {:ok, result}
    end
  end
end
