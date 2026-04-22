defmodule Intellispark.Recognition.Changes.RecordResend do
  use Ash.Resource.Change

  alias Intellispark.Recognition.Notifiers.Emails

  @impl true
  def change(changeset, _opts, _ctx) do
    changeset
    |> Ash.Changeset.force_change_attribute(:resent_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _changeset, high_five ->
      Emails.notify_resent(high_five)
      {:ok, high_five}
    end)
  end
end
