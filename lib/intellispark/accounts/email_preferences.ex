defmodule Intellispark.Accounts.EmailPreferences do
  @moduledoc """
  Per-user, per-event email opt-in/opt-out lookup. Default-in semantics:
  if a user has no record for an event kind, they are opted IN.
  """

  @valid_kinds ~w(high_five_received high_five_resent flag_assigned flag_followup
                  action_due weekly_digest)

  @spec valid_kinds() :: [String.t()]
  def valid_kinds, do: @valid_kinds

  @spec opted_in?(map() | nil, String.t()) :: boolean()
  def opted_in?(nil, _kind), do: false

  def opted_in?(%{email_preferences: prefs}, kind) when is_map(prefs) do
    Map.get(prefs, kind, true)
  end

  def opted_in?(_user, _kind), do: true
end
