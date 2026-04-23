defmodule Intellispark.Teams.ExternalPersonTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Teams
  alias Intellispark.Teams.ExternalPerson

  setup do: setup_world()

  describe ":create" do
    test "creates an external person scoped to the school", %{school: school, admin: admin} do
      ep =
        create_external_person!(admin, school, %{
          first_name: "Renee",
          last_name: "Guardian",
          relationship_kind: :guardian,
          email: "r@example.com"
        })

      assert ep.first_name == "Renee"
      assert ep.last_name == "Guardian"
      assert ep.relationship_kind == :guardian
      assert ep.email == "r@example.com"
      assert ep.school_id == school.id
      assert ep.added_by_id == admin.id
    end

    test "rejects unsupported relationship_kind", %{school: school, admin: admin} do
      assert {:error, _} =
               Teams.create_external_person("X", "Y", :unknown_atom, %{},
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "paper_trail" do
    test "create + update produce versions with school_id", %{school: school, admin: admin} do
      ep = create_external_person!(admin, school)

      {:ok, _} =
        Ash.update(ep, %{phone: "555-0123"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {:ok, versions} =
        ExternalPerson.Version
        |> Ash.Query.filter(version_source_id == ^ep.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      actions = Enum.map(versions, & &1.version_action_name) |> Enum.sort()
      assert :create in actions
      assert :update in actions
      assert Enum.all?(versions, &(&1.school_id == school.id))
    end
  end

  describe "tenant isolation" do
    test "school A external persons invisible from school B", %{
      school: school_a,
      admin: admin,
      district: district
    } do
      school_b = add_second_school!(district, "Other High", "oh")
      _ep_a = create_external_person!(admin, school_a)

      rows_b =
        ExternalPerson
        |> Ash.Query.set_tenant(school_b.id)
        |> Ash.read!(authorize?: false)

      assert rows_b == []
    end
  end

  describe "calculations" do
    test "display_name combines first + last", %{school: school, admin: admin} do
      ep = create_external_person!(admin, school, %{first_name: "Mira", last_name: "Patel"})
      ep = Ash.load!(ep, [:display_name], actor: admin, authorize?: false)
      assert ep.display_name == "Mira Patel"
    end
  end
end
