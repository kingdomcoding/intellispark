defmodule Intellispark.Support.InterventionLibraryItemTest do
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

  test "PRO-tier admin can create a library item", %{admin: admin, school: school} do
    {:ok, item} =
      Support.create_intervention_library_item("Flex Time", :tier_2,
        actor: admin,
        tenant: school.id
      )

    assert item.title == "Flex Time"
    assert item.mtss_tier == :tier_2
    assert item.active? == true
    assert item.default_duration_days == 30
  end

  test "Starter-tier admin cannot create", %{admin: admin, school: school} do
    _ = set_school_tier!(school, :starter)
    starter = Ash.load!(school, [:subscription], authorize?: false)
    starter_admin = Map.put(admin, :current_school, starter)

    assert {:error, %Ash.Error.Forbidden{}} =
             Support.create_intervention_library_item("Nope", :tier_1,
               actor: starter_admin,
               tenant: starter.id
             )
  end

  test "plain teacher cannot create", %{school: school} do
    teacher = register_teacher!(school)
    teacher = Map.put(teacher, :current_school, school)

    assert {:error, %Ash.Error.Forbidden{}} =
             Support.create_intervention_library_item("Nope", :tier_1,
               actor: teacher,
               tenant: school.id
             )
  end
end
