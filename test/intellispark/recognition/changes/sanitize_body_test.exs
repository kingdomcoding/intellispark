defmodule Intellispark.Recognition.Changes.SanitizeBodyTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  alias Intellispark.Recognition

  setup do: setup_world()

  test "strips <script> tag from body on :send_to_student", %{school: school, admin: admin} do
    student = create_student!(school)

    hf =
      send_high_five!(admin, school, student, %{
        body: "<p>ok</p><script>alert(1)</script>",
        recipient_email: "k@example.com"
      })

    refute hf.body =~ "<script"
    assert hf.body =~ "<p>ok</p>"
  end

  test "keeps allowed tags (strong, em, u, ul, ol, li)", %{school: school, admin: admin} do
    student = create_student!(school)

    body =
      "<p>a <strong>b</strong> <em>c</em> <u>d</u></p><ul><li>e</li></ul><ol><li>f</li></ol>"

    hf =
      send_high_five!(admin, school, student, %{body: body, recipient_email: "k@example.com"})

    assert hf.body =~ "<strong>b</strong>"
    assert hf.body =~ "<em>c</em>"
    assert hf.body =~ "<u>d</u>"
    assert hf.body =~ "<li>e</li>"
    assert hf.body =~ "<li>f</li>"
  end

  test "preserves plain text without tags", %{school: school, admin: admin} do
    student = create_student!(school)

    hf =
      send_high_five!(admin, school, student, %{
        body: "plain text here",
        recipient_email: "k@example.com"
      })

    assert hf.body == "plain text here"
  end

  test "sanitizes on :resend with edited body", %{school: school, admin: admin} do
    student = create_student!(school)
    hf = send_high_five!(admin, school, student, %{body: "<p>old</p>", recipient_email: "k@example.com"})

    {:ok, resent} =
      Recognition.resend_high_five(
        hf,
        %{body: "<p>new</p><script>x</script>"},
        actor: admin,
        tenant: school.id
      )

    refute resent.body =~ "<script"
    assert resent.body =~ "<p>new</p>"
  end
end
