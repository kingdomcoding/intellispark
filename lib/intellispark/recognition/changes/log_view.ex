defmodule Intellispark.Recognition.Changes.LogView do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _cs, high_five ->
      ua = context.arguments[:user_agent] || "unknown"
      ip_hash = context.arguments[:ip_hash]

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
