defmodule Intellispark.Recognition.HighFiveTemplateTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  alias Intellispark.Recognition.HighFiveTemplate

  setup do: setup_world()

  describe ":create" do
    test "stamps school_id from tenant", %{school: school} do
      t = create_template!(school, %{title: "Hello"})
      assert t.school_id == school.id
    end

    test "active? defaults to true", %{school: school} do
      t = create_template!(school)
      assert t.active? == true
    end
  end

  describe "identity" do
    test "unique title per school raises on duplicate", %{school: school} do
      _ = create_template!(school, %{title: "Once"})

      assert_raise Ash.Error.Invalid, fn ->
        create_template!(school, %{title: "Once"})
      end
    end

    test "same title is allowed in a different school", %{district: district, school: school} do
      other = add_second_school!(district)
      _ = create_template!(school, %{title: "Shared"})
      t2 = create_template!(other, %{title: "Shared"})
      assert t2.school_id == other.id
    end
  end

  describe "category enum" do
    test "rejects invalid atoms", %{school: school} do
      assert_raise Ash.Error.Invalid, fn ->
        create_template!(school, %{category: :not_a_real_category})
      end
    end

    test "accepts all six documented categories", %{school: school} do
      [:achievement, :behavior, :attendance, :effort, :kindness, :custom]
      |> Enum.each(fn cat ->
        t = create_template!(school, %{category: cat})
        assert t.category == cat
      end)
    end
  end

  describe ":update" do
    test "writes a version row on update", %{school: school, admin: admin} do
      require Ash.Query

      t = create_template!(school)

      {:ok, _} =
        Intellispark.Recognition.update_high_five_template(t, %{body: "New body"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      versions =
        HighFiveTemplate.Version
        |> Ash.Query.filter(version_source_id == ^t.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      names = Enum.map(versions, & &1.version_action_name)
      assert :create in names
      assert :update in names
    end
  end
end
