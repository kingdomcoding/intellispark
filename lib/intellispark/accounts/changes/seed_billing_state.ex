defmodule Intellispark.Accounts.Changes.SeedBillingState do
  @moduledoc """
  After-action change on `School.:create` that atomically seeds a
  `:starter` SchoolSubscription + an `:school_profile` SchoolOnboardingState.
  Runs with `authorize?: false` since the creating actor may not yet have
  membership in the new school.
  """

  use Ash.Resource.Change

  alias Intellispark.Billing.SchoolOnboardingState
  alias Intellispark.Billing.SchoolSubscription

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, school ->
      SchoolSubscription
      |> Ash.Changeset.for_create(:create, %{school_id: school.id}, authorize?: false)
      |> Ash.create!()

      SchoolOnboardingState
      |> Ash.Changeset.for_create(:create, %{school_id: school.id}, authorize?: false)
      |> Ash.create!()

      {:ok, school}
    end)
  end
end
