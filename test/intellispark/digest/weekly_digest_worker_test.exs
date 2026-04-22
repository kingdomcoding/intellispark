defmodule Intellispark.Digest.WeeklyDigestWorkerTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures
  import Intellispark.RecognitionFixtures
  import Swoosh.TestAssertions

  alias Intellispark.Accounts
  alias Intellispark.Digest.WeeklyDigestWorker

  setup do: setup_world()

  test "worker sends email when user has activity + opted in",
       %{school: school, admin: admin} do
    student = create_student!(school)
    _ = create_team_membership!(admin, school, student, admin, :counselor)

    _ =
      send_high_five!(admin, school, student, %{
        title: "Great work",
        body: "Body",
        recipient_email: "k@example.com"
      })

    perform_job(WeeklyDigestWorker, %{})

    assert_email_sent(fn email ->
      assert email.subject == "New activity from last week"
      assert hd(email.to) == {"", to_string(admin.email)}
    end)
  end

  test "user opted out of weekly_digest → no email sent",
       %{school: school, admin: admin} do
    student = create_student!(school)
    _ = create_team_membership!(admin, school, student, admin, :counselor)

    {:ok, _} =
      Accounts.set_email_preference(admin, "weekly_digest", false,
        actor: admin,
        authorize?: false
      )

    _ =
      send_high_five!(admin, school, student, %{
        title: "x",
        body: "x",
        recipient_email: "k@example.com"
      })

    perform_job(WeeklyDigestWorker, %{})

    assert_no_email_sent()
  end

  test "all sections empty → no email sent (skip-empty)",
       %{school: school, admin: admin} do
    student = create_student!(school)
    _ = create_team_membership!(admin, school, student, admin, :counselor)

    perform_job(WeeklyDigestWorker, %{})

    assert_no_email_sent()
  end
end
