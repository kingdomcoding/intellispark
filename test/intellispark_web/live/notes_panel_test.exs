defmodule IntellisparkWeb.NotesPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  alias Intellispark.Accounts.{User, UserSchoolMembership}

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty-state when no notes", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "NoNotes", last_name: "Case"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No notes for this student yet"
  end

  test "lists existing notes", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "HasNotes", last_name: "Case"})
    _ = create_note!(admin, school, student, %{body: "first note body"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "first note body"
  end

  test "pin button moves note above unpinned", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Pinned", last_name: "First"})
    n1 = create_note!(admin, school, student, %{body: "later note"})
    _n2 = create_note!(admin, school, student, %{body: "earlier note"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html =
      lv
      |> element("#note-#{n1.id} button[aria-label='Pin note']")
      |> render_click()

    # Pinned body is rendered before the unpinned body (order in the DOM)
    later_idx = :binary.match(html, "later note") |> elem(0)
    earlier_idx = :binary.match(html, "earlier note") |> elem(0)
    assert later_idx < earlier_idx
  end

  test "teacher cannot see a sensitive note", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Sens", last_name: "Note"})
    _ = create_note!(admin, school, student, %{body: "HIDDEN CLINICAL", sensitive?: true})

    teacher = register_teacher!(school)

    {:ok, _lv, html} = conn |> log_in_user(teacher) |> live(~p"/students/#{student.id}")

    refute html =~ "HIDDEN CLINICAL"
  end

  defp register_teacher!(school) do
    user =
      Ash.create!(
        User,
        %{
          email: "teach-#{System.unique_integer([:positive])}@sandbox.edu",
          password: "supersecret123",
          password_confirmation: "supersecret123"
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{
          user_id: user.id,
          school_id: school.id,
          role: :teacher,
          source: :manual
        },
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end
end
