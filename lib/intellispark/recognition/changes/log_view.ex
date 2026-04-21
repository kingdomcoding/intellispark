defmodule Intellispark.Recognition.Changes.LogView do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    ua = Ash.Changeset.get_argument(changeset, :user_agent) || "unknown"
    ip_hash = Ash.Changeset.get_argument(changeset, :ip_hash)

    Ash.Changeset.after_action(changeset, fn _cs, high_five ->
      Ash.create!(
        Intellispark.Recognition.HighFiveView,
        %{
          high_five_id: high_five.id,
          user_agent: ua,
          ip_hash: ip_hash
        },
        tenant: high_five.school_id,
        authorize?: false
      )

      {:ok, high_five}
    end)
  end
end
