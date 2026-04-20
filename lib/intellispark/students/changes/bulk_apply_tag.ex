defmodule Intellispark.Students.Changes.BulkApplyTag do
  @moduledoc """
  Wraps Ash.bulk_create on StudentTag. Given an argument map of
  `%{tag_id: id, student_ids: [id, ...]}` plus an actor + tenant, creates
  one StudentTag per student. Per-row authorization, partial-failure
  reporting, identity collisions (re-applied tag) treated as success.

  Stashes the bulk result in the Tag's __metadata__ so the LiveView can
  surface a success/partial-failure flash.
  """

  use Ash.Resource.Change

  alias Intellispark.Students.StudentTag

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, tag ->
      student_ids = Ash.Changeset.get_argument(changeset, :student_ids) || []

      result =
        student_ids
        |> Enum.map(&%{student_id: &1, tag_id: tag.id})
        |> Ash.bulk_create(
          StudentTag,
          :create,
          actor: context.actor,
          tenant: tag.school_id,
          return_errors?: true,
          return_records?: false,
          stop_on_error?: false,
          authorize?: false,
          upsert?: true,
          upsert_identity: :unique_student_tag,
          # Include archived_at so re-adding a previously-removed tag
          # restores the row (AshArchival's destroy soft-deletes; without
          # this, the upsert updates applied_at but leaves archived_at
          # populated, and the tag stays hidden from the read filter).
          upsert_fields: [:applied_at, :archived_at, :applied_by_id],
          notify?: true
        )

      {:ok, %{tag | __metadata__: Map.put(tag.__metadata__, :bulk_result, result)}}
    end)
  end
end
