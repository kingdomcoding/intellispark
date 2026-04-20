defmodule Intellispark.Support.NoteTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  require Ash.Query

  alias Intellispark.Support
  alias Intellispark.Support.Note

  setup do: setup_world()

  describe ":create" do
    test "stamps author_id", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student, %{body: "hello"})

      assert note.author_id == admin.id
      assert note.body == "hello"
      assert note.pinned? == false
      assert note.sensitive? == false
    end

    test "allows sensitive? true on create", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student, %{sensitive?: true})
      assert note.sensitive? == true
    end
  end

  describe "pin/unpin" do
    test ":pin sets pinned? + pinned_at", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student)

      pinned = pin_note!(note, admin)
      assert pinned.pinned? == true
      assert pinned.pinned_at != nil
    end

    test ":unpin clears pinned? + pinned_at", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student) |> pin_note!(admin)

      unpinned = unpin_note!(note, admin)
      assert unpinned.pinned? == false
      assert unpinned.pinned_at == nil
    end

    test "pin → unpin → pin cycles pinned_at", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student) |> pin_note!(admin)
      first_pinned_at = note.pinned_at

      :timer.sleep(10)

      repinned = note |> unpin_note!(admin) |> pin_note!(admin)

      assert repinned.pinned? == true
      assert DateTime.compare(repinned.pinned_at, first_pinned_at) == :gt
    end
  end

  describe ":update" do
    test "writes a Note.Version row", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student, %{body: "orig"})

      {:ok, _} =
        Support.update_note(note, %{body: "edited"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      versions =
        Note.Version
        |> Ash.Query.filter(version_source_id == ^note.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      names = Enum.map(versions, & &1.version_action_name)
      assert :create in names
      assert :update in names
    end
  end

  describe "calculations" do
    test "preview returns first 80 chars", %{school: school, admin: admin} do
      student = create_student!(school)

      note =
        create_note!(admin, school, student, %{
          body: String.duplicate("x", 200)
        })

      loaded = Ash.load!(note, [:preview], actor: admin, tenant: school.id)
      assert String.length(loaded.preview) == 80
    end

    test "edited? starts false, flips true after update", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student, %{body: "orig"})

      initial = Ash.load!(note, [:edited?], actor: admin, tenant: school.id)
      assert initial.edited? == false

      :timer.sleep(2_100)

      {:ok, updated} =
        Support.update_note(note, %{body: "new"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      loaded = Ash.load!(updated, [:edited?], actor: admin, tenant: school.id)
      assert loaded.edited? == true
    end
  end
end
