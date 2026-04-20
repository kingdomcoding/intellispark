defmodule Intellispark.Support.SupportTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  require Ash.Query

  alias Intellispark.Support
  alias Intellispark.Support.Support, as: SupportPlan

  setup do: setup_world()

  describe ":create" do
    test "lands in :offered + stamps offered_by_id", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student, %{title: "Mental Health Services"})

      assert support.status == :offered
      assert support.offered_by_id == admin.id
      assert support.title == "Mental Health Services"
    end

    test "accepts nil dates (open-ended)", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student)

      assert support.starts_at == nil
      assert support.ends_at == nil
    end

    test "round-trips a date range", %{school: school, admin: admin} do
      student = create_student!(school)
      starts = Date.utc_today()
      ends = Date.add(starts, 30)

      support =
        create_support!(admin, school, student, %{
          starts_at: starts,
          ends_at: ends
        })

      assert support.starts_at == starts
      assert support.ends_at == ends
    end
  end

  describe "state machine" do
    test ":accept transitions :offered → :in_progress", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      accepted = accept_support!(support, admin)
      assert accepted.status == :in_progress
    end

    test ":decline transitions :offered → :declined + stores reason", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      declined = decline_support!(support, admin, "not a fit")
      assert declined.status == :declined
      assert declined.decline_reason == "not a fit"
    end

    test ":complete transitions :in_progress → :completed", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      accepted = accept_support!(support, admin)
      done = complete_support!(accepted, admin)
      assert done.status == :completed
    end

    test ":accept from :in_progress raises NoMatchingTransition", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      accepted = accept_support!(support, admin)

      assert {:error, _} =
               Support.accept_support(accepted,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end

    test ":complete from :offered raises NoMatchingTransition", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      support = create_support!(admin, school, student)

      assert {:error, _} =
               Support.complete_support(support,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end

    test ":decline from :in_progress raises NoMatchingTransition", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      accepted = accept_support!(support, admin)

      assert {:error, _} =
               Support.decline_support(accepted, %{reason: nil},
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "paper trail" do
    test "writes a Support.Version row per transition", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      _ = accept_support!(support, admin)

      versions =
        SupportPlan.Version
        |> Ash.Query.filter(version_source_id == ^support.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      action_names = Enum.map(versions, & &1.version_action_name)
      assert :create in action_names
      assert :accept in action_names
    end
  end

  describe "open_supports_count aggregate" do
    test "increments on offer and decrements on complete", %{school: school, admin: admin} do
      require Ash.Query
      student = create_student!(school)
      support = create_support!(admin, school, student)

      loaded1 =
        Ash.load!(student, [:open_supports_count], actor: admin, tenant: school.id)

      assert loaded1.open_supports_count == 1

      support |> accept_support!(admin) |> complete_support!(admin)

      loaded2 =
        Ash.load!(student, [:open_supports_count], actor: admin, tenant: school.id)

      assert loaded2.open_supports_count == 0
    end
  end
end
