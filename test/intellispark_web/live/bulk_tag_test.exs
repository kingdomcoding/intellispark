defmodule IntellisparkWeb.BulkTagTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students.StudentTag

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "select students → open tag modal → apply tag → DB rows created", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    s1 = create_student!(school, %{first_name: "Ada", last_name: "L"})
    s2 = create_student!(school, %{first_name: "Linus", last_name: "T"})
    tag = create_tag!(school, %{name: "BulkTarget"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> element(~s|input[phx-click="toggle_select"][phx-value-id="#{s1.id}"]|)
    |> render_click()

    lv
    |> element(~s|input[phx-click="toggle_select"][phx-value-id="#{s2.id}"]|)
    |> render_click()

    modal_html =
      lv
      |> element(~s|button[phx-value-action="tag"]|)
      |> render_click()

    assert modal_html =~ "BulkTarget"

    lv
    |> element(~s|button[phx-click="apply_tag"][phx-value-tag_id="#{tag.id}"]|)
    |> render_click()

    {:ok, rows} =
      StudentTag
      |> Ash.Query.filter(tag_id == ^tag.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read(authorize?: false)

    assert length(rows) == 2
    assert Enum.all?(rows, &(&1.applied_by_id == admin.id))
    assert MapSet.new(Enum.map(rows, & &1.student_id)) == MapSet.new([s1.id, s2.id])
  end
end
