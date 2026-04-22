defmodule Intellispark.Billing.SchoolOnboardingStateTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Billing

  setup do: setup_world()

  test "create seeds :school_profile step", %{school: school, admin: admin} do
    {:ok, state} =
      Billing.get_onboarding_state_by_school(school.id, actor: admin, tenant: school.id)

    assert state.current_step == :school_profile
    assert state.school_profile_completed_at == nil
    assert state.completed_at == nil
  end

  test "advance_step stamps the previous step's completed_at",
       %{school: school, admin: admin} do
    {:ok, state} =
      Billing.get_onboarding_state_by_school(school.id, actor: admin, tenant: school.id)

    {:ok, advanced} =
      Billing.advance_onboarding_step(state, :invite_coadmins, actor: admin, tenant: school.id)

    assert advanced.current_step == :invite_coadmins
    assert advanced.school_profile_completed_at != nil
    assert advanced.invite_coadmins_completed_at == nil
  end

  test "complete sets :done + completed_at", %{school: school, admin: admin} do
    {:ok, state} =
      Billing.get_onboarding_state_by_school(school.id, actor: admin, tenant: school.id)

    {:ok, finished} =
      Billing.complete_onboarding(state, actor: admin, tenant: school.id)

    assert finished.current_step == :done
    assert finished.completed_at != nil
  end
end
