defmodule IntellisparkWeb.OnboardingLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Billing

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "non-district-admin redirects away from /onboarding", %{conn: conn, school: school} do
    counselor = create_user_with_role!(school, :counselor)

    assert {:error, {:live_redirect, %{to: "/students", flash: flash}}} =
             conn |> log_in_user(counselor) |> live(~p"/onboarding")

    assert flash["error"] =~ "district admins"
  end

  test "district admin walks the wizard to :done",
       %{conn: conn, school: school, admin: admin} do
    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/onboarding")

    # Step 1: school profile — skip
    lv |> element(~s|button[phx-click="skip_step"]|) |> render_click()
    # Step 2: invite co-admins — skip
    lv |> element(~s|button[phx-click="skip_step"]|) |> render_click()
    # Step 3: starter tags — skip (seeding path exercised separately)
    lv |> element(~s|button[phx-click="skip_step"]|) |> render_click()
    # Step 4: SIS provider — continue (only button on the step)
    lv |> element(~s|button[phx-click="skip_step"]|) |> render_click()
    # Step 5: pick tier — choose :pro, which advances to :done
    lv
    |> element(~s|button[phx-click="choose_tier"][phx-value-tier="pro"]|)
    |> render_click()

    state =
      Billing.get_onboarding_state_by_school!(school.id, actor: admin, tenant: school.id)

    assert state.current_step == :done
    assert state.completed_at != nil
  end
end
