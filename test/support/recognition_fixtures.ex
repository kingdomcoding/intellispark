defmodule Intellispark.RecognitionFixtures do
  @moduledoc """
  Test fixtures for Phase 6 Recognition resources
  (HighFiveTemplate, HighFive, HighFiveView). Builds on top of
  StudentsFixtures.setup_world/0.
  """

  alias Intellispark.Recognition
  alias Intellispark.Recognition.{HighFive, HighFiveTemplate}

  def create_template!(school, attrs \\ %{}) do
    defaults = %{
      title: "Template #{System.unique_integer([:positive])}",
      body: "Great job!",
      category: :effort,
      active?: true
    }

    HighFiveTemplate
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs),
      tenant: school.id
    )
    |> Ash.create!(authorize?: false)
  end

  def send_high_five!(actor, school, student, attrs \\ %{}) do
    defaults = %{
      student_id: student.id,
      title: Map.get(attrs, :title, "Nice work"),
      body: Map.get(attrs, :body, "Keep it up!"),
      recipient_email: Map.get(attrs, :recipient_email, "recipient@example.com")
    }

    HighFive
    |> Ash.Changeset.for_create(:send_to_student, Map.merge(defaults, attrs),
      tenant: school.id,
      actor: actor
    )
    |> Ash.create!(authorize?: false)
  end

  def record_view!(high_five, attrs \\ %{}) do
    ua = Map.get(attrs, :user_agent, "Mozilla/5.0")
    ip_hash = Map.get(attrs, :ip_hash, "sha:abc")

    {:ok, updated} =
      Recognition.record_high_five_view(high_five, ua, ip_hash,
        tenant: high_five.school_id,
        authorize?: false
      )

    updated
  end

  def bulk_send!(actor, school, student_ids, template) do
    {:ok, result} =
      Recognition.bulk_send_high_five(student_ids, template.id,
        actor: actor,
        tenant: school.id
      )

    result
  end
end
