defmodule Intellispark.Recognition.BulkSendTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  require Ash.Query

  alias Intellispark.Recognition
  alias Intellispark.Recognition.HighFive
  alias Intellispark.Recognition.Oban.DeliverHighFiveEmailWorker

  setup do: setup_world()

  describe "bulk_send_to_students" do
    test "sends N high 5s when all students have email", %{
      school: school,
      admin: admin
    } do
      template = create_template!(school, %{title: "Batch"})

      students =
        for i <- 1..5 do
          create_student!(school, %{
            first_name: "Bulk#{i}",
            email: "bulk#{i}@example.com"
          })
        end

      ids = Enum.map(students, & &1.id)

      {:ok, %Ash.BulkResult{records: records, errors: errs}} =
        Recognition.bulk_send_high_five(ids, template.id,
          actor: admin,
          tenant: school.id
        )

      assert length(records) == 5
      assert errs in [nil, []]
    end

    test "enqueues one :emails job per high 5", %{school: school, admin: admin} do
      template = create_template!(school, %{title: "Jobs"})
      student1 = create_student!(school, %{email: "a@example.com"})
      student2 = create_student!(school, %{email: "b@example.com"})

      {:ok, _} =
        Recognition.bulk_send_high_five(
          [student1.id, student2.id],
          template.id,
          actor: admin,
          tenant: school.id
        )

      assert_enqueued(worker: DeliverHighFiveEmailWorker)
      assert all_enqueued(worker: DeliverHighFiveEmailWorker) |> length() == 2
    end

    test "partial failure when some students lack emails", %{
      school: school,
      admin: admin
    } do
      template = create_template!(school, %{title: "Partial"})

      with_email = create_student!(school, %{email: "good@example.com"})
      without_email = create_student!(school, %{email: nil})

      {:ok, %Ash.BulkResult{records: records, errors: errs}} =
        Recognition.bulk_send_high_five(
          [with_email.id, without_email.id],
          template.id,
          actor: admin,
          tenant: school.id
        )

      assert length(records) == 1
      assert is_list(errs) and errs != []
    end

    test "all inserted rows use the same title + body from the template", %{
      school: school,
      admin: admin
    } do
      template =
        create_template!(school, %{
          title: "Identical title",
          body: "Identical body."
        })

      students =
        for i <- 1..3,
            do: create_student!(school, %{first_name: "Bulk#{i}", email: "u#{i}@e.com"})

      ids = Enum.map(students, & &1.id)

      {:ok, _} =
        Recognition.bulk_send_high_five(ids, template.id,
          actor: admin,
          tenant: school.id
        )

      hfs =
        HighFive
        |> Ash.Query.filter(template_id == ^template.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(hfs) == 3
      assert Enum.all?(hfs, &(&1.title == "Identical title"))
      assert Enum.all?(hfs, &(&1.body == "Identical body."))
    end
  end
end
