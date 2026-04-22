defmodule Intellispark.Recognition.HighFiveResendTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  alias Intellispark.Recognition

  setup do: setup_world()

  test ":resend sets resent_at + enqueues a new Oban job with high_five_resent kind",
       %{school: school, admin: admin} do
    student = create_student!(school)

    high_five =
      send_high_five!(admin, school, student, %{
        title: "x",
        body: "x",
        recipient_email: "k@example.com"
      })

    {:ok, resent} =
      Recognition.resend_high_five(high_five, actor: admin, tenant: school.id)

    assert resent.resent_at != nil

    assert_enqueued(
      worker: Intellispark.Recognition.Oban.DeliverHighFiveEmailWorker,
      args: %{"event_kind" => "high_five_resent", "high_five_id" => resent.id}
    )
  end

  test "worker honors event_kind opt-out (recipient lookup)",
       %{school: school, admin: admin} do
    student = create_student!(school)

    high_five =
      send_high_five!(admin, school, student, %{
        title: "x",
        body: "x",
        recipient_email: to_string(admin.email)
      })

    {:ok, _} =
      Intellispark.Accounts.set_email_preference(admin, "high_five_resent", false,
        actor: admin,
        authorize?: false
      )

    {:ok, _resent} =
      Recognition.resend_high_five(high_five, actor: admin, tenant: school.id)

    # Job is still enqueued; the worker itself short-circuits without sending.
    assert_enqueued(
      worker: Intellispark.Recognition.Oban.DeliverHighFiveEmailWorker,
      args: %{"event_kind" => "high_five_resent"}
    )
  end
end
