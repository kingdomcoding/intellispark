defmodule Intellispark.Accounts.PoliciesTest do
  use Intellispark.DataCase, async: false

  alias Intellispark.Accounts.{District, School, User, UserSchoolMembership}

  setup do
    {:ok, district} =
      Ash.create(District, %{name: "Sandbox", slug: "sandbox"}, authorize?: false)

    {:ok, school} =
      Ash.create(
        School,
        %{name: "Sandbox High", slug: "sh", district_id: district.id},
        authorize?: false
      )

    admin =
      register!("admin@sandbox.edu", "supersecret123")
      |> attach_district!(district.id)
      |> with_membership!(school.id, :admin)

    teacher =
      register!("teacher@sandbox.edu", "supersecret123")
      |> attach_district!(district.id)
      |> with_membership!(school.id, :teacher)

    %{district: district, school: school, admin: admin, teacher: teacher}
  end

  describe "User read policy" do
    test "user can read themselves", %{teacher: teacher} do
      assert {:ok, _} = Ash.get(User, teacher.id, actor: teacher)
    end

    test "teacher cannot read admin", %{teacher: teacher, admin: admin} do
      assert {:error, _} = Ash.get(User, admin.id, actor: teacher)
    end

    test "district admin can read any user in the district", %{admin: admin, teacher: teacher} do
      assert {:ok, _} = Ash.get(User, teacher.id, actor: admin)
    end

    test "no actor cannot read users", %{teacher: teacher} do
      assert {:error, _} = Ash.get(User, teacher.id, actor: nil)
    end
  end

  describe "UserSchoolMembership read policy" do
    test "user sees own memberships", %{teacher: teacher} do
      {:ok, memberships} = Ash.read(UserSchoolMembership, actor: teacher)
      assert Enum.all?(memberships, &(&1.user_id == teacher.id))
    end

    test "district admin sees all memberships in district", %{admin: admin, teacher: teacher} do
      {:ok, memberships} = Ash.read(UserSchoolMembership, actor: admin)
      user_ids = memberships |> Enum.map(& &1.user_id) |> Enum.uniq()
      assert teacher.id in user_ids
      assert admin.id in user_ids
    end

    test "no actor cannot read memberships" do
      {:ok, memberships} = Ash.read(UserSchoolMembership, actor: nil)
      assert memberships == []
    end
  end

  describe "School read policy" do
    test "member can read their school", %{teacher: teacher, school: school} do
      assert {:ok, _} = Ash.get(School, school.id, actor: teacher)
    end

    test "non-member with no district admin role cannot read other schools", %{
      district: district,
      teacher: teacher
    } do
      {:ok, other_school} =
        Ash.create(
          School,
          %{name: "Other High", slug: "other", district_id: district.id},
          authorize?: false
        )

      assert {:error, _} = Ash.get(School, other_school.id, actor: teacher)
    end

    test "district admin reads all schools in their district", %{
      district: district,
      admin: admin
    } do
      {:ok, other_school} =
        Ash.create(
          School,
          %{name: "Other High", slug: "other", district_id: district.id},
          authorize?: false
        )

      assert {:ok, _} = Ash.get(School, other_school.id, actor: admin)
    end
  end

  defp register!(email, password) do
    Ash.create!(
      Intellispark.Accounts.User,
      %{email: email, password: password, password_confirmation: password},
      action: :register_with_password,
      authorize?: false
    )
  end

  defp attach_district!(user, district_id) do
    Ash.update!(user, %{district_id: district_id}, action: :set_district, authorize?: false)
  end

  defp with_membership!(user, school_id, role) do
    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: user.id, school_id: school_id, role: role, source: :manual},
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end
end
