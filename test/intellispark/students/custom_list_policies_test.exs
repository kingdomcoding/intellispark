defmodule Intellispark.Students.CustomListPoliciesTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Students

  setup do: setup_world()

  defp create_list!(actor, school, attrs \\ %{}) do
    name = Map.get(attrs, :name, "List #{System.unique_integer([:positive])}")

    Students.create_custom_list!(name, %{tag_ids: []},
      actor: actor,
      tenant: school.id,
      authorize?: false
    )
  end

  test "owner can update their own list", %{school: school, admin: admin} do
    list = create_list!(admin, school)

    assert {:ok, _} =
             Students.update_custom_list(list, %{name: "Renamed"},
               actor: admin,
               tenant: school.id
             )
  end

  test "owner can archive their own list", %{school: school, admin: admin} do
    list = create_list!(admin, school)

    assert :ok = Students.archive_custom_list(list, actor: admin, tenant: school.id)
  end

  test "non-owner non-admin teacher cannot update", %{school: school, admin: admin} do
    list = create_list!(admin, school)
    teacher = register_teacher!(school)

    assert {:error, %Ash.Error.Forbidden{}} =
             Students.update_custom_list(list, %{name: "Pwned"},
               actor: teacher,
               tenant: school.id
             )
  end

  test "non-owner admin in same school can update", %{school: school, admin: admin} do
    list = create_list!(admin, school)
    other_admin = register_admin!(school)

    assert {:ok, _} =
             Students.update_custom_list(list, %{name: "By other admin"},
               actor: other_admin,
               tenant: school.id
             )
  end

  test "non-owner admin in same school can archive", %{school: school, admin: admin} do
    list = create_list!(admin, school)
    other_admin = register_admin!(school)

    assert :ok =
             Students.archive_custom_list(list,
               actor: other_admin,
               tenant: school.id
             )
  end
end
