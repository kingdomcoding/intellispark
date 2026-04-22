defmodule Intellispark.Teams.Actions.AddMembersFromRoster do
  @moduledoc """
  Bulk-upsert team memberships from a roster sync. Called by Phase 11
  RosterImporter for each student's current teachers. Idempotent via
  the `unique_per_student_user_role` identity — second run with the
  same inputs produces the same rows (updated `source / added_at`
  columns, no new PKs).
  """

  use Ash.Resource.Actions.Implementation

  alias Intellispark.Teams.TeamMembership

  @impl true
  def run(input, _opts, context) do
    student_id = input.arguments.student_id
    staff_ids = input.arguments.staff_user_ids
    role = input.arguments.role
    tenant = context.tenant

    payloads =
      Enum.map(staff_ids, fn uid ->
        %{
          student_id: student_id,
          user_id: uid,
          role: role,
          source: :roster_auto,
          added_at: DateTime.utc_now()
        }
      end)

    result =
      Ash.bulk_create(
        payloads,
        TeamMembership,
        :create,
        tenant: tenant,
        upsert?: true,
        upsert_identity: :unique_per_student_user_role,
        upsert_fields: [:source, :added_at, :updated_at],
        return_records?: true,
        return_errors?: true,
        stop_on_error?: false,
        notify?: true,
        authorize?: false
      )

    {:ok, result.records || []}
  end
end
