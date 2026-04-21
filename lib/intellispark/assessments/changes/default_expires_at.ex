defmodule Intellispark.Assessments.Changes.DefaultExpiresAt do
  @moduledoc false
  use Ash.Resource.Change

  @default_window_days 14

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :expires_at) do
      nil ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :expires_at,
          DateTime.add(DateTime.utc_now(), @default_window_days * 86_400, :second)
        )

      _ ->
        changeset
    end
  end
end
