defmodule Intellispark.Assessments.Resiliency.Changes.StampAssignment do
  @moduledoc false
  use Ash.Resource.Change

  alias Intellispark.Assessments.Resiliency.QuestionBank

  @token_bytes 24
  @default_expiry_days 14

  @impl true
  def change(changeset, _opts, context) do
    token = :crypto.strong_rand_bytes(@token_bytes) |> Base.url_encode64(padding: false)
    expires_at = DateTime.add(DateTime.utc_now(), @default_expiry_days * 86_400, :second)

    changeset
    |> Ash.Changeset.change_attribute(:token, token)
    |> Ash.Changeset.change_attribute(:version, QuestionBank.current_version())
    |> Ash.Changeset.change_attribute(:expires_at, expires_at)
    |> Ash.Changeset.change_attribute(:assigned_by_id, context.actor.id)
  end
end
