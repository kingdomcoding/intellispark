defmodule IntellisparkWeb.StudentLive.AboutTabTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Assessments
  alias Intellispark.Integrations

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)

    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)

    Map.merge(
      %{conn: Phoenix.ConnTest.build_conn()},
      Map.put(ctx, :school, school)
    )
  end

  defp visit_about(conn, admin, student) do
    {:ok, _lv, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=about")

    html
  end

  defp seed_xello(school, student) do
    {:ok, _} =
      Integrations.upsert_xello_profile(
        %{
          student_id: student.id,
          personality_style: %{"helper" => 0.5, "organizer" => 0.3, "persuader" => 0.2},
          learning_style: %{"visual" => 50, "auditory" => 30, "tactile" => 20},
          education_goals: "Go to college",
          favorite_career_clusters: ["STEM"],
          skills: ["Communication"],
          interests: ["Physics"],
          birthplace: "California",
          live_in: "Massachusetts",
          family_roots: "Indian",
          suggested_clusters: ["Healthcare"],
          completed_lessons: ["L1", "L2", "L3"]
        },
        tenant: school.id,
        authorize?: false
      )
  end

  defp seed_resiliency_scores(school, student) do
    for {skill, value, level} <- [
          {:confidence, 4.0, :high},
          {:persistence, 3.0, :moderate},
          {:organization, 2.0, :low},
          {:getting_along, 4.0, :high},
          {:resilience, 3.5, :moderate},
          {:curiosity, 3.0, :moderate}
        ] do
      {:ok, _} =
        Assessments.upsert_resiliency_skill_score(
          student.id,
          skill,
          value,
          level,
          3,
          tenant: school.id,
          authorize?: false
        )
    end
  end

  test "PRO + Xello + resiliency → all 3 zones render with data", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Hap", last_name: "Py"})
    seed_xello(school, student)
    seed_resiliency_scores(school, student)

    html = visit_about(conn, admin, student)

    assert html =~ "Personality Style"
    assert html =~ "Helper"
    assert html =~ "Learning Style"
    assert html =~ "Visual Learner"
    assert html =~ "Lessons Complete"
    assert html =~ "3 of 8"
    assert html =~ "Go to college"
    assert html =~ "California"
    assert html =~ "Resiliency Skills"
    assert html =~ "Confidence"
    assert html =~ "Academic Risk Index"
    assert html =~ "Suggested Clusters"
    assert html =~ "Healthcare"
  end

  test "PRO + no Xello → hero row shows Connect Xello empty state, resiliency still renders", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "No", last_name: "Xello"})
    seed_resiliency_scores(school, student)

    html = visit_about(conn, admin, student)

    assert html =~ "Connect Xello to populate"
    assert html =~ "Resiliency Skills"
    assert html =~ "Confidence"
  end

  test "PRO + Xello + no resiliency → shows 'Assign a resiliency survey' empty state", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "No", last_name: "Res"})
    seed_xello(school, student)

    html = visit_about(conn, admin, student)

    assert html =~ "Assign a resiliency survey"
  end

  test "Starter tier → tier-gated CTA shown, Xello data hidden", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    _ = set_school_tier!(school, :starter)
    starter = Ash.load!(school, [:subscription], authorize?: false)
    student = create_student!(starter, %{first_name: "St", last_name: "Arter"})
    seed_xello(starter, student)
    seed_resiliency_scores(starter, student)

    html = visit_about(conn, admin, student)

    assert html =~ "ScholarCentric + Xello require a PRO plan" or
             html =~ "ScholarCentric requires a PRO plan"
  end

  test "render uses preloaded xello_profile + resiliency_skill_scores assigns", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Re", last_name: "Load"})
    seed_xello(school, student)
    seed_resiliency_scores(school, student)

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=about")

    rendered = render(lv)
    assert rendered =~ "Visual Learner"
    assert rendered =~ "3 of 8"
  end
end
