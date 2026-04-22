defmodule Intellispark.Billing.Changes.StampStepCompletion do
  @moduledoc """
  On `:advance_step`, stamps the corresponding `_completed_at` field for
  the step the row is moving AWAY from (read from the data before
  `set_attribute(:current_step, arg(:step))` is applied). Called before
  the `set_attribute` change so we stamp the OLD step's completion,
  not the NEW one's.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.data do
      %{current_step: step} when not is_nil(step) ->
        case stamp_field(step) do
          nil -> changeset
          field -> Ash.Changeset.force_change_attribute(changeset, field, DateTime.utc_now())
        end

      _ ->
        changeset
    end
  end

  defp stamp_field(:school_profile), do: :school_profile_completed_at
  defp stamp_field(:invite_coadmins), do: :invite_coadmins_completed_at
  defp stamp_field(:starter_tags), do: :starter_tags_completed_at
  defp stamp_field(:sis_provider), do: :sis_provider_completed_at
  defp stamp_field(:pick_tier), do: :pick_tier_completed_at
  defp stamp_field(_), do: nil
end
