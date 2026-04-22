defmodule Intellispark.Accounts.EmailPreferencesTest do
  use ExUnit.Case, async: true

  alias Intellispark.Accounts.EmailPreferences

  test "default-in: missing key returns true" do
    user = %{email_preferences: %{}}
    assert EmailPreferences.opted_in?(user, "high_five_received")
    assert EmailPreferences.opted_in?(user, "weekly_digest")
  end

  test "respects false override" do
    user = %{email_preferences: %{"flag_assigned" => false}}
    refute EmailPreferences.opted_in?(user, "flag_assigned")
    assert EmailPreferences.opted_in?(user, "weekly_digest")
  end

  test "respects true override" do
    user = %{email_preferences: %{"weekly_digest" => true}}
    assert EmailPreferences.opted_in?(user, "weekly_digest")
  end

  test "nil user returns false" do
    refute EmailPreferences.opted_in?(nil, "high_five_received")
  end

  test "valid_kinds returns the 6 supported event kinds" do
    kinds = EmailPreferences.valid_kinds()

    assert "high_five_received" in kinds
    assert "high_five_resent" in kinds
    assert "flag_assigned" in kinds
    assert "flag_followup" in kinds
    assert "action_due" in kinds
    assert "weekly_digest" in kinds
    assert length(kinds) == 6
  end
end
