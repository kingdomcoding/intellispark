defmodule IntellisparkWeb.CustomListComposerTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Students
  alias Intellispark.Students.CustomList

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "save view button is disabled when no filters active",
       %{conn: conn, admin: admin} do
    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students")

    assert html =~ "Save view as"
    assert html =~ ~r/<button[^>]*phx-click="open_save_view"[^>]*disabled/
  end

  test "selecting a tag enables save view + opens composer",
       %{conn: conn, school: school, admin: admin} do
    tag = create_tag!(school, %{name: "ELL"})
    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> render_change("filter_change", %{"filter" => %{"tag_ids" => [tag.id]}})

    enabled_html =
      lv
      |> element(~s|button[phx-click="open_save_view"]|)
      |> render_click()

    assert enabled_html =~ "Save view as…"
    assert enabled_html =~ "List name"
    assert enabled_html =~ "Filters in this view"
    assert enabled_html =~ "Tags:"
  end

  test "submit composer creates list + navigates to /lists/:id",
       %{conn: conn, school: school, admin: admin} do
    tag = create_tag!(school, %{name: "ELL"})
    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> render_change("filter_change", %{"filter" => %{"tag_ids" => [tag.id]}})

    lv
    |> element(~s|button[phx-click="open_save_view"]|)
    |> render_click()

    lv
    |> form("#list-composer-form", %{"list" => %{"name" => "ELL kids"}})
    |> render_submit()

    {path, _flash} = assert_redirect(lv, 1000)
    assert path =~ ~r{^/lists/[a-f0-9-]+$}

    assert [%CustomList{name: "ELL kids"}] =
             Students.list_custom_lists!(actor: admin, tenant: school.id)
  end

  test "rename from /lists card menu", %{conn: conn, school: school, admin: admin} do
    {:ok, _list} =
      Students.create_custom_list("Old name", %{tag_ids: []},
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    {:ok, lv, html} = conn |> log_in_user(admin) |> live(~p"/lists")
    assert html =~ "Old name"

    lv
    |> element(~s|button[phx-click="open_rename"]|)
    |> render_click()

    lv
    |> form("#list-composer-form", %{"list" => %{"name" => "New name"}})
    |> render_submit()

    new_html = render(lv)
    assert new_html =~ "List updated."
    assert new_html =~ "New name"
    refute new_html =~ "Old name"
  end

  test "delete from /lists card menu archives the row",
       %{conn: conn, school: school, admin: admin} do
    {:ok, list} =
      Students.create_custom_list("Doomed", %{tag_ids: []},
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    {:ok, lv, html} = conn |> log_in_user(admin) |> live(~p"/lists")
    assert html =~ "Doomed"

    new_html =
      lv
      |> element(~s|button[phx-click="delete_list"][phx-value-id="#{list.id}"]|)
      |> render_click()

    refute new_html =~ "Doomed"
    assert Students.list_custom_lists!(actor: admin, tenant: school.id) == []
  end

  test "non-owner teacher does not see another user's private list",
       %{conn: conn, school: school, admin: admin} do
    teacher = register_teacher!(school)

    {:ok, _list} =
      Students.create_custom_list("Private", %{tag_ids: []},
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    {:ok, _lv, html} = conn |> log_in_user(teacher) |> live(~p"/lists")

    refute html =~ "Private"
  end

  test "edit-filters round-trip preserves dimension filters set in JSON",
       %{conn: conn, school: school, admin: admin} do
    tag = create_tag!(school, %{name: "Cohort"})

    {:ok, list} =
      Students.create_custom_list(
        "Belonging Low",
        %{tag_ids: [], belonging: :low},
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/students?from_list=#{list.id}")

    lv
    |> render_change("filter_change", %{"filter" => %{"tag_ids" => [tag.id]}})

    lv
    |> element(~s|button[phx-click="open_save_view"]|)
    |> render_click()

    lv
    |> form("#list-composer-form", %{"list" => %{"name" => "Belonging Low"}})
    |> render_submit()

    reloaded =
      Students.get_custom_list!(list.id, actor: admin, tenant: school.id)

    assert reloaded.filters.belonging == :low
    assert tag.id in reloaded.filters.tag_ids
  end
end
