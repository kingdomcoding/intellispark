defmodule IntellisparkWeb.HighFiveResendModalTest do
  use IntellisparkWeb.ConnCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "clicking re-send icon opens modal pre-filled with title + body",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Re", last_name: "Send"})

    hf =
      send_high_five!(admin, school, student, %{
        title: "Original",
        body: "<p>msg</p>",
        recipient_email: "k@example.com"
      })

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html =
      lv
      |> element(~s|button[phx-click="open_resend_high_five_modal"][phx-value-id="#{hf.id}"]|)
      |> render_click()

    assert html =~ "Re-send High 5 to"
    assert html =~ "Original"
    assert html =~ "Re-send"
  end

  test "submitting edited resend form updates the record and flashes",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Edit", last_name: "Body"})

    hf =
      send_high_five!(admin, school, student, %{
        title: "Old",
        body: "<p>old</p>",
        recipient_email: "k@example.com"
      })

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    lv
    |> element(~s|button[phx-click="open_resend_high_five_modal"][phx-value-id="#{hf.id}"]|)
    |> render_click()

    lv
    |> element(~s|form[phx-submit="save"]|)
    |> render_submit(%{"high_five" => %{"title" => "Updated", "body" => "<p>new</p>"}})

    reloaded = Ash.reload!(hf, authorize?: false)
    assert reloaded.title == "Updated"
    assert reloaded.body == "<p>new</p>"
    assert reloaded.resent_at != nil

    assert render(lv) =~ "High 5 re-sent."
  end

  test "re-sent annotation appears on the Hub row after resend",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Annot", last_name: "Ated"})

    hf =
      send_high_five!(admin, school, student, %{
        title: "T",
        body: "b",
        recipient_email: "k@example.com"
      })

    {:ok, _resent} =
      Intellispark.Recognition.resend_high_five(hf, %{}, actor: admin, tenant: school.id)

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "re-sent"
  end
end
