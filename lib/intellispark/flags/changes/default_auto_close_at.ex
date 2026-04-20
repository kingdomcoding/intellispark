defmodule Intellispark.Flags.Changes.DefaultAutoCloseAt do
  @moduledoc false
  use Ash.Resource.Change

  @thirty_days 30 * 24 * 3600

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :auto_close_at) do
      nil ->
        ts = DateTime.utc_now() |> DateTime.add(@thirty_days, :second)
        Ash.Changeset.force_change_attribute(changeset, :auto_close_at, ts)

      _ ->
        changeset
    end
  end
end
