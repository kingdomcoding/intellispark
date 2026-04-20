defmodule Intellispark.SupportFixtures do
  @moduledoc """
  Test fixtures for Phase 5 Support resources (Action, Support, Note).
  Builds on StudentsFixtures.setup_world/0.
  """

  alias Intellispark.Support
  alias Intellispark.Support.{Action, Note}
  alias Intellispark.Support.Support, as: SupportPlan

  def create_action!(actor, school, student, assignee, attrs \\ %{}) do
    desc = Map.get(attrs, :description, "action #{System.unique_integer([:positive])}")

    input =
      %{
        student_id: student.id,
        assignee_id: assignee.id,
        description: desc
      }
      |> maybe_put(:due_on, Map.get(attrs, :due_on))

    Action
    |> Ash.Changeset.for_create(:create, input, tenant: school.id, actor: actor)
    |> Ash.create!(authorize?: false)
  end

  def complete_action!(action, actor) do
    {:ok, done} =
      Support.complete_action(action,
        actor: actor,
        tenant: action.school_id,
        authorize?: false
      )

    done
  end

  def cancel_action!(action, actor, reason \\ nil) do
    {:ok, cancelled} =
      Support.cancel_action(action, %{reason: reason},
        actor: actor,
        tenant: action.school_id,
        authorize?: false
      )

    cancelled
  end

  def create_support!(actor, school, student, attrs \\ %{}) do
    title = Map.get(attrs, :title, "support #{System.unique_integer([:positive])}")

    input =
      %{student_id: student.id, title: title}
      |> maybe_put(:description, Map.get(attrs, :description))
      |> maybe_put(:starts_at, Map.get(attrs, :starts_at))
      |> maybe_put(:ends_at, Map.get(attrs, :ends_at))
      |> maybe_put(:provider_staff_id, Map.get(attrs, :provider_staff_id))

    SupportPlan
    |> Ash.Changeset.for_create(:create, input, tenant: school.id, actor: actor)
    |> Ash.create!(authorize?: false)
  end

  def accept_support!(support, actor) do
    {:ok, s} =
      Support.accept_support(support,
        actor: actor,
        tenant: support.school_id,
        authorize?: false
      )

    s
  end

  def decline_support!(support, actor, reason \\ nil) do
    {:ok, s} =
      Support.decline_support(support, %{reason: reason},
        actor: actor,
        tenant: support.school_id,
        authorize?: false
      )

    s
  end

  def complete_support!(support, actor) do
    {:ok, s} =
      Support.complete_support(support,
        actor: actor,
        tenant: support.school_id,
        authorize?: false
      )

    s
  end

  def create_note!(actor, school, student, attrs \\ %{}) do
    body = Map.get(attrs, :body, "note #{System.unique_integer([:positive])}")

    input =
      %{student_id: student.id, body: body}
      |> maybe_put(:sensitive?, Map.get(attrs, :sensitive?))

    Note
    |> Ash.Changeset.for_create(:create, input, tenant: school.id, actor: actor)
    |> Ash.create!(authorize?: false)
  end

  def pin_note!(note, actor) do
    {:ok, n} =
      Support.pin_note(note, actor: actor, tenant: note.school_id, authorize?: false)

    n
  end

  def unpin_note!(note, actor) do
    {:ok, n} =
      Support.unpin_note(note, actor: actor, tenant: note.school_id, authorize?: false)

    n
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
