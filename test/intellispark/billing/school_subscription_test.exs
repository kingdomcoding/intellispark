defmodule Intellispark.Billing.SchoolSubscriptionTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Billing

  setup do: setup_world()

  test "creating a School seeds a :starter subscription", %{school: school, admin: admin} do
    {:ok, sub} =
      Billing.get_subscription_by_school(school.id, actor: admin, tenant: school.id)

    assert sub
    assert sub.tier == :starter
    assert sub.status == :active
  end

  test "district admin can set_tier", %{school: school, admin: admin} do
    {:ok, sub} =
      Billing.get_subscription_by_school(school.id, actor: admin, tenant: school.id)

    {:ok, updated} = Billing.set_tier(sub, :pro, actor: admin, tenant: school.id)
    assert updated.tier == :pro
  end

  test "non-district-admin cannot set_tier", %{school: school, admin: admin} do
    counselor = create_user_with_role!(school, :counselor)

    {:ok, sub} =
      Billing.get_subscription_by_school(school.id, actor: admin, tenant: school.id)

    assert {:error, %Ash.Error.Forbidden{}} =
             Billing.set_tier(sub, :pro, actor: counselor, tenant: school.id)
  end

  test ":unique_school identity blocks double-seed", %{school: school} do
    assert_raise Ash.Error.Invalid, fn ->
      Billing.SchoolSubscription
      |> Ash.Changeset.for_create(:create, %{school_id: school.id}, authorize?: false)
      |> Ash.create!()
    end
  end
end
