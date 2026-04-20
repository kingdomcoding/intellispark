defmodule IntellisparkWeb.StudentShowTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students
  alias Intellispark.Students.StudentTag

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  describe "signed-out" do
    test "redirects /students/:id to /sign-in", %{conn: conn, school: school} do
      student = create_student!(school, %{first_name: "Signed", last_name: "Out"})
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/students/#{student.id}")
    end
  end

  describe "signed-in rendering" do
    test "renders display_name, grade, tag chips, count badges", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Scan", last_name: "Ner", grade_level: 10})
      tag = create_tag!(school, %{name: "FirstTag"})
      apply_tag!(admin, school, student, tag)

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      assert html =~ "Scan Ner"
      assert html =~ "Grade 10"
      assert html =~ "FirstTag"
      assert html =~ "High-5s"
      assert html =~ "Flags"
      assert html =~ "Supports"
    end

    test "uses preferred_name when set", %{conn: conn, school: school, admin: admin} do
      student =
        create_student!(school, %{first_name: "Marcus", last_name: "J", preferred_name: "MJ"})

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      assert html =~ "MJ"
    end
  end

  describe "demographics edit modal" do
    test "open modal, save preferred_name update", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Edit", last_name: "Me"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      html =
        lv
        |> element("button[phx-click=\"open_edit_modal\"]", "Edit profile")
        |> render_click()

      assert html =~ "Edit profile"

      html =
        lv
        |> form("form[phx-submit=\"save_profile\"]", form: %{preferred_name: "EditedName"})
        |> render_submit()

      assert html =~ "EditedName"
      refute html =~ "phx-submit=\"save_profile\""
    end

    test "invalid grade_level shows validation error", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Bad", last_name: "Grade"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      lv
      |> element("button[phx-click=\"open_edit_modal\"]", "Edit profile")
      |> render_click()

      html =
        lv
        |> form("form[phx-submit=\"save_profile\"]", form: %{grade_level: "20"})
        |> render_change()

      assert html =~ "phx-submit=\"save_profile\""
      assert html =~ "20"
    end
  end

  describe "inline tag editor" do
    test "adding a tag produces a StudentTag row", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Add", last_name: "Tag"})
      tag = create_tag!(school, %{name: "LiveAddTag"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      html =
        lv
        |> element(
          "#add-tag-details-inline-tag-editor button[phx-value-tag_id=\"#{tag.id}\"]",
          tag.name
        )
        |> render_click()

      assert html =~ "LiveAddTag"

      count =
        StudentTag
        |> Ash.Query.filter(student_id == ^student.id and tag_id == ^tag.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)
        |> length()

      assert count == 1
    end
  end

  describe "inline status editor" do
    test "picking a status updates current_status_id + timeline", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Status", last_name: "Pick"})
      status = create_status!(school, %{name: "LivePickStatus"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      html =
        lv
        |> form("form[phx-change=\"set_status\"]", status_id: status.id)
        |> render_change()

      assert html =~ "LivePickStatus"

      {:ok, reloaded} =
        Students.get_student(student.id, actor: admin, tenant: school.id)

      assert reloaded.current_status_id == status.id
    end
  end

  describe "PubSub realtime" do
    test "broadcast on students:<id> triggers a reload", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Push", last_name: "Ed"})

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

      Ash.update!(student, %{preferred_name: "Pushed!"},
        action: :update,
        tenant: school.id,
        actor: admin,
        authorize?: false
      )

      Phoenix.PubSub.broadcast(
        Intellispark.PubSub,
        "students:#{student.id}",
        %Phoenix.Socket.Broadcast{topic: "students:#{student.id}", event: "update"}
      )

      :timer.sleep(50)
      assert render(lv) =~ "Pushed!"
    end
  end
end
