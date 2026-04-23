defmodule IntellisparkWeb.StudentLive.NewInterventionModalTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Support
  alias Intellispark.Support.Support, as: SupportPlan

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)

    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    admin = Map.put(ctx.admin, :current_school, school)

    Map.merge(
      %{conn: Phoenix.ConnTest.build_conn()},
      ctx |> Map.put(:school, school) |> Map.put(:admin, admin)
    )
  end

  defp seed_item(school, admin, title) do
    {:ok, item} =
      Support.create_intervention_library_item(
        title,
        :tier_2,
        %{description: "A helpful intervention", default_duration_days: 30},
        actor: admin,
        tenant: school.id
      )

    item
  end

  defp visit_hub(conn, admin, student) do
    conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")
  end

  test "list view renders active library items and opens form on click", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    _ = seed_item(school, admin, "Flex Time")
    _ = seed_item(school, admin, "Check & Connect")

    student = create_student!(school, %{first_name: "Mo", last_name: "Dal"})

    {:ok, lv, _} = visit_hub(conn, admin, student)

    lv
    |> element("button[phx-click=\"open_new_intervention_modal\"]")
    |> render_click()

    html = render(lv)
    assert html =~ "Choose an intervention"
    assert html =~ "Flex Time"
    assert html =~ "Check &amp; Connect"
  end

  test "submitting the form creates a Support with intervention_library_item_id", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    item = seed_item(school, admin, "Flex Time")
    student = create_student!(school, %{first_name: "Su", last_name: "Bmit"})

    {:ok, lv, _} = visit_hub(conn, admin, student)

    lv
    |> element("button[phx-click=\"open_new_intervention_modal\"]")
    |> render_click()

    lv |> element(~s|button[phx-value-id="#{item.id}"]|) |> render_click()

    lv
    |> form("form[phx-submit=\"create_support\"]", provider_staff_id: "")
    |> render_submit()

    assert {:ok, [support]} =
             SupportPlan
             |> Ash.Query.filter(student_id == ^student.id)
             |> Ash.Query.set_tenant(school.id)
             |> Ash.read(authorize?: false)

    assert support.intervention_library_item_id == item.id
    assert support.title == "Flex Time"
    refute render(lv) =~ ~s(id="new-intervention-modal")
  end

  test "+ Intervention button is hidden on Starter tier", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    _ = set_school_tier!(school, :starter)
    starter = Ash.load!(school, [:subscription], authorize?: false)
    student = create_student!(starter, %{first_name: "St", last_name: "Arter"})

    {:ok, _lv, html} = visit_hub(conn, admin, student)

    refute html =~ "+ Intervention"
  end
end
