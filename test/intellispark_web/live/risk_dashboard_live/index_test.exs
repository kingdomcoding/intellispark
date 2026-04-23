defmodule IntellisparkWeb.RiskDashboardLive.IndexTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Assessments

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

  defp seed_scores_for(school, student, skill_levels) do
    for {skill, value, level} <- skill_levels do
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

  defp high_band_scores do
    [
      {:confidence, 2.0, :low},
      {:persistence, 2.0, :low},
      {:organization, 2.0, :low},
      {:getting_along, 2.0, :low},
      {:resilience, 2.0, :low},
      {:curiosity, 2.0, :low}
    ]
  end

  defp moderate_band_scores do
    [
      {:confidence, 3.0, :moderate},
      {:persistence, 3.0, :moderate},
      {:organization, 3.0, :moderate},
      {:getting_along, 3.0, :moderate},
      {:resilience, 3.0, :moderate},
      {:curiosity, 3.0, :moderate}
    ]
  end

  test "mounts for PRO district admin and renders ranked list", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    high = create_student!(school, %{first_name: "Hi", last_name: "Gh"})
    moderate = create_student!(school, %{first_name: "Mo", last_name: "D"})

    seed_scores_for(school, high, high_band_scores())
    seed_scores_for(school, moderate, moderate_band_scores())

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/risk")

    assert html =~ "Risk Dashboard"
    assert html =~ "Hi Gh"
    assert html =~ "Mo D"
    high_idx = :binary.match(html, "Hi Gh") |> elem(0)
    moderate_idx = :binary.match(html, "Mo D") |> elem(0)
    assert high_idx < moderate_idx
  end

  test "band filter narrows list to one band", %{conn: conn, school: school, admin: admin} do
    high = create_student!(school, %{first_name: "Uh", last_name: "Oh"})
    low = create_student!(school, %{first_name: "Al", last_name: "Lgood"})

    seed_scores_for(school, high, high_band_scores())

    seed_scores_for(school, low, [
      {:confidence, 5.0, :high},
      {:persistence, 5.0, :high},
      {:organization, 5.0, :high},
      {:getting_along, 5.0, :high},
      {:resilience, 5.0, :high},
      {:curiosity, 5.0, :high}
    ])

    {:ok, lv, _} = conn |> log_in_user(admin) |> live(~p"/students/risk")

    html =
      lv
      |> form("form[phx-change=\"filter\"]", band: "high", skill: "all")
      |> render_change()

    assert html =~ "Uh Oh"
    refute html =~ "Al Lgood"
  end

  test "skill filter narrows to students whose contributing_factors include the skill", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    primarily_low_confidence =
      create_student!(school, %{first_name: "Con", last_name: "Low"})

    seed_scores_for(school, primarily_low_confidence, [
      {:confidence, 1.0, :low},
      {:persistence, 3.5, :moderate},
      {:organization, 3.5, :moderate},
      {:getting_along, 3.5, :moderate},
      {:resilience, 3.0, :moderate},
      {:curiosity, 3.0, :moderate}
    ])

    low_persistence =
      create_student!(school, %{first_name: "Per", last_name: "Low"})

    seed_scores_for(school, low_persistence, [
      {:confidence, 3.5, :moderate},
      {:persistence, 1.0, :low},
      {:organization, 3.5, :moderate},
      {:getting_along, 3.5, :moderate},
      {:resilience, 3.0, :moderate},
      {:curiosity, 3.0, :moderate}
    ])

    {:ok, lv, _} = conn |> log_in_user(admin) |> live(~p"/students/risk")

    html =
      lv
      |> form("form[phx-change=\"filter\"]", band: "all", skill: "confidence")
      |> render_change()

    assert html =~ "Con Low"
    refute html =~ "Per Low"
  end

  test "Starter-tier actor redirected to /students", %{conn: conn, school: school, admin: admin} do
    _ = set_school_tier!(school, :starter)
    _ = Ash.load!(school, [:subscription], authorize?: false)

    assert {:error, {:live_redirect, %{to: "/students"}}} =
             conn |> log_in_user(admin) |> live(~p"/students/risk")
  end
end
