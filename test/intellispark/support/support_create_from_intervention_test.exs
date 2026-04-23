defmodule Intellispark.Support.SupportCreateFromInterventionTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  alias Intellispark.Support

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    admin = Map.put(ctx.admin, :current_school, school)
    ctx |> Map.put(:school, school) |> Map.put(:admin, admin)
  end

  defp seed_library_item(school, admin, attrs \\ %{}) do
    defaults = %{
      title: "Check & Connect",
      mtss_tier: :tier_3,
      default_duration_days: 90,
      description: "Daily mentor check-in"
    }

    merged = Map.merge(defaults, attrs)

    {:ok, item} =
      Support.create_intervention_library_item(
        merged.title,
        merged.mtss_tier,
        %{description: merged.description, default_duration_days: merged.default_duration_days},
        actor: admin,
        tenant: school.id
      )

    item
  end

  test "creates a Support with intervention_library_item_id stamped", %{
    admin: admin,
    school: school
  } do
    student = create_student!(school, %{first_name: "Cr", last_name: "Eate"})
    item = seed_library_item(school, admin)

    {:ok, support} =
      Support.create_support_from_intervention(
        student.id,
        "Overridden Title",
        %{intervention_library_item_id: item.id},
        actor: admin,
        tenant: school.id
      )

    assert support.intervention_library_item_id == item.id
    assert support.title == "Overridden Title"
  end

  test "prefills title + description + ends_at when input leaves them blank", %{
    admin: admin,
    school: school
  } do
    student = create_student!(school, %{first_name: "Pre", last_name: "Fill"})
    item = seed_library_item(school, admin)

    {:ok, support} =
      Support.create_support_from_intervention(
        student.id,
        nil,
        %{intervention_library_item_id: item.id, starts_at: ~D[2026-04-23]},
        actor: admin,
        tenant: school.id
      )

    assert support.title == "Check & Connect"
    assert support.description == "Daily mentor check-in"
    assert support.ends_at == Date.add(~D[2026-04-23], 90)
    assert support.intervention_library_item_id == item.id
  end

  test "Starter-tier admin cannot call :create_from_intervention", %{admin: admin, school: school} do
    item = seed_library_item(school, admin)
    _ = set_school_tier!(school, :starter)
    starter = Ash.load!(school, [:subscription], authorize?: false)
    starter_admin = Map.put(admin, :current_school, starter)
    student = create_student!(starter, %{first_name: "No", last_name: "Tier"})

    assert {:error, %Ash.Error.Forbidden{}} =
             Support.create_support_from_intervention(
               student.id,
               "Attempt",
               %{intervention_library_item_id: item.id},
               actor: starter_admin,
               tenant: starter.id
             )
  end
end
