defmodule IntellisparkWeb.SurveyLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    %{school: school, admin: admin, district: district} = setup_world()

    template = create_template!(school, %{name: "Survey Live Tmpl"})
    q1 = create_question!(template, %{prompt: "What's your name?", position: 1, required?: true})
    q2 = create_question!(template, %{prompt: "Favorite color?", position: 2, required?: false})
    q3 = create_question!(template, %{prompt: "Anything else?", position: 3, required?: false})
    published = publish_template!(template, admin)

    student = create_student!(school, %{first_name: "Survey", last_name: "Taker"})
    a = assign_survey!(admin, school, student, published)

    %{
      conn: Phoenix.ConnTest.build_conn(),
      school: school,
      admin: admin,
      district: district,
      student: student,
      template: published,
      assignment: a,
      q1: q1,
      q2: q2,
      q3: q3
    }
  end

  test "valid token renders question 1 with progress 0 of N",
       %{conn: conn, assignment: a} do
    {:ok, _lv, html} = live(conn, ~p"/surveys/#{a.token}")

    assert html =~ "What&#39;s your name?"
    assert html =~ "0 of 3 answered"
  end

  test "blur saves response + bumps progress bar",
       %{conn: conn, assignment: a, q1: q1} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    html =
      lv
      |> element("textarea[phx-blur='save_answer']")
      |> render_blur(%{"question_id" => q1.id, "value" => "Marcus"})

    assert html =~ "1 of 3 answered"
  end

  test "Next advances to question 2",
       %{conn: conn, assignment: a} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    html = lv |> element("button", "Next") |> render_click()
    assert html =~ "Favorite color?"
  end

  test "Previous goes back to question 1",
       %{conn: conn, assignment: a} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    _ = lv |> element("button", "Next") |> render_click()
    html = lv |> element("button", "Previous") |> render_click()

    assert html =~ "What&#39;s your name?"
  end

  test "Submit with required missing renders banner + keeps assignment unsubmitted",
       %{conn: conn, assignment: a, school: school} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    _ = lv |> element("button", "Next") |> render_click()
    _ = lv |> element("button", "Next") |> render_click()
    html = lv |> element("button", "Submit") |> render_click()

    refute html =~ "Thanks for your response"
    assert html =~ "Please answer all required questions before submitting."
    assert html =~ "your name?"

    reloaded =
      Ash.get!(Intellispark.Assessments.SurveyAssignment, a.id,
        tenant: school.id,
        authorize?: false
      )

    refute reloaded.state == :submitted
  end

  test "submit banner clears on next navigation",
       %{conn: conn, assignment: a} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    _ = lv |> element("button", "Next") |> render_click()
    _ = lv |> element("button", "Next") |> render_click()
    _ = lv |> element("button", "Submit") |> render_click()
    html = lv |> element("button", "Previous") |> render_click()

    refute html =~ "Please answer all required questions before submitting."
  end

  test "Submit with all required answered transitions to thank-you screen",
       %{conn: conn, assignment: a, q1: q1} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    _ =
      lv
      |> element("textarea[phx-blur='save_answer']")
      |> render_blur(%{"question_id" => q1.id, "value" => "Marcus"})

    _ = lv |> element("button", "Next") |> render_click()
    _ = lv |> element("button", "Next") |> render_click()
    html = lv |> element("button", "Submit") |> render_click()

    assert html =~ "Thanks for your response!"
  end

  test "unknown token renders Survey not found fallback", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/surveys/garbage-token-xyz")
    assert html =~ "Survey not found"
  end

  test "phx-change form submit (answer_text key) also saves the response",
       %{conn: conn, assignment: a, q1: q1} do
    {:ok, lv, _html} = live(conn, ~p"/surveys/#{a.token}")

    html =
      lv
      |> element("form[phx-change='save_answer']")
      |> render_change(%{"question_id" => q1.id, "answer_text" => "Ada"})

    assert html =~ "1 of 3 answered"
  end
end
