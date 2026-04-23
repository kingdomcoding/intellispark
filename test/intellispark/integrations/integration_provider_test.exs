defmodule Intellispark.Integrations.IntegrationProviderTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations

  setup do
    world = setup_world()

    admin_with_school =
      world.admin
      |> Map.put(:current_school, Ash.load!(world.school, [:subscription], authorize?: false))

    {:ok, world: world, admin: admin_with_school}
  end

  test "district admin can create :csv provider", %{world: %{school: school}, admin: admin} do
    assert {:ok, provider} =
             Integrations.create_provider(
               %{provider_type: :csv, name: "School CSV"},
               actor: admin,
               tenant: school.id
             )

    assert provider.provider_type == :csv
    assert provider.active? == true
  end

  test "starter-tier admin cannot create :xello provider",
       %{world: %{school: school}, admin: admin} do
    # school defaults to :starter from Phase 18.5 seed
    assert {:error, %Ash.Error.Forbidden{}} =
             Integrations.create_provider(
               %{provider_type: :xello, name: "Xello"},
               actor: admin,
               tenant: school.id
             )
  end

  test "PRO-tier admin can create :xello provider",
       %{world: %{school: school}, admin: admin} do
    set_school_tier!(school, :pro)

    admin_pro =
      admin
      |> Map.put(:current_school, Ash.load!(school, [:subscription], authorize?: false))

    assert {:ok, provider} =
             Integrations.create_provider(
               %{provider_type: :xello, name: "Xello"},
               actor: admin_pro,
               tenant: school.id
             )

    assert provider.provider_type == :xello
  end

  test "credentials encrypted at rest", %{world: %{school: school}, admin: admin} do
    {:ok, provider} =
      Integrations.create_provider(
        %{
          provider_type: :csv,
          name: "Test",
          credentials: %{"api_key" => "sk_super_secret"}
        },
        actor: admin,
        tenant: school.id
      )

    raw =
      Intellispark.Repo.query!(
        "SELECT credentials FROM integration_providers WHERE id = $1",
        [Ecto.UUID.dump!(provider.id)]
      )

    [[binary]] = raw.rows
    assert is_binary(binary)
    refute binary =~ "sk_super_secret"
  end

  test "activate/deactivate toggles active?", %{world: %{school: school}, admin: admin} do
    {:ok, provider} =
      Integrations.create_provider(
        %{provider_type: :csv, name: "T"},
        actor: admin,
        tenant: school.id
      )

    {:ok, deactivated} =
      Integrations.deactivate_provider(provider, actor: admin, tenant: school.id)

    refute deactivated.active?

    {:ok, reactivated} =
      Integrations.activate_provider(deactivated, actor: admin, tenant: school.id)

    assert reactivated.active?
  end
end
