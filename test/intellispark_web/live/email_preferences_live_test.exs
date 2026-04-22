defmodule IntellisparkWeb.EmailPreferencesLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "renders all 6 toggles, all checked by default", %{conn: conn, admin: admin} do
    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/me/email-preferences")

    assert html =~ "Email preferences"
    assert html =~ "High 5 received"
    assert html =~ "Flag assigned to me"
    assert html =~ "Weekly digest"

    assert Regex.scan(~r/checked="checked"|checked=""|<input[^>]*\schecked/, html)
           |> length() >= 6
  end

  test "toggling a checkbox updates the user's email_preferences",
       %{conn: conn, admin: admin} do
    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/me/email-preferences")

    lv
    |> element(~s|input[phx-value-kind="weekly_digest"]|)
    |> render_click()

    reloaded = Ash.reload!(admin, authorize?: false)
    assert reloaded.email_preferences["weekly_digest"] == false
  end
end
