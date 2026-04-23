defmodule IntellisparkWeb.StudentLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  import Intellispark.FlagsFixtures
  import Intellispark.SupportFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  describe "signed-out access" do
    test "GET /students redirects to /sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/students")
    end
  end

  describe "signed-in" do
    test "renders seeded students", %{conn: conn, school: school, admin: admin} do
      create_student!(school, %{first_name: "Ada", last_name: "Lovelace"})
      create_student!(school, %{first_name: "Linus", last_name: "Torvalds"})

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students")

      assert html =~ "All Students"
      assert html =~ "Ada Lovelace"
      assert html =~ "Linus Torvalds"
    end

    test "search narrows the list", %{conn: conn, school: school, admin: admin} do
      create_student!(school, %{first_name: "Ada", last_name: "Lovelace"})
      create_student!(school, %{first_name: "Linus", last_name: "Torvalds"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

      html =
        lv
        |> form("form[phx-change=search]", %{"q" => "Linus"})
        |> render_change()

      assert html =~ "Linus Torvalds"
      refute html =~ "Ada Lovelace"
    end

    test "clicking a student name navigates to /students/:id", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      s = create_student!(school, %{first_name: "Ada", last_name: "Lovelace"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

      assert {:error, {:live_redirect, %{to: path}}} =
               lv
               |> element(~s|tr#student-#{s.id} a|)
               |> render_click()

      assert path =~ "/students/#{s.id}"
      assert path =~ "return_to=/students"
    end

    test "filter bar renders the new tag/status/grade/enrollment controls",
         %{conn: conn, school: school, admin: admin} do
      create_student!(school, %{first_name: "Ada", last_name: "L"})

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students")

      assert html =~ "Ada L"
      assert html =~ "Tags"
      assert html =~ "Status"
      assert html =~ "Grade"
      assert html =~ "Enrollment"
      assert html =~ "Save view as"
    end

    test "Phase 3 retrofit C — popover renders top-3 open flags + supports for a row", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Pop", last_name: "Over"})
      type = create_flag_type!(school, %{name: "Academic"})

      for desc <- ["Late assignments", "Skipping math", "Behavior outburst"] do
        create_flag!(admin, school, student, type, %{
          description: desc,
          short_description: desc
        })
      end

      create_support!(admin, school, student, %{title: "Daily check-in"})
      create_support!(admin, school, student, %{title: "Tutoring slot"})

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students")

      assert html =~ ~s(id="student-#{student.id}-flags-popover")
      assert html =~ ~s(id="student-#{student.id}-supports-popover")
      assert html =~ "Late assignments"
      assert html =~ "Daily check-in"
    end

    test "only students in the current school are visible", %{
      conn: conn,
      school: school,
      district: district,
      admin: admin
    } do
      other = add_second_school!(district)
      create_student!(school, %{first_name: "Mine", last_name: "Student"})
      create_student!(other, %{first_name: "Theirs", last_name: "Student"})

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students")

      assert html =~ "Mine Student"
      refute html =~ "Theirs Student"
    end
  end
end
