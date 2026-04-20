defmodule IntellisparkWeb.StudentLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

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

      assert path == ~p"/students/#{s.id}"
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
