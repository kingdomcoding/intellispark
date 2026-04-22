defmodule Intellispark.Digest.WeeklyDigestComposer do
  @moduledoc """
  Builds a per-recipient weekly digest payload. Pure module: no side
  effects, no Oban, no Mailer. Output is a `%Digest{}` struct that the
  worker either emails or skips when empty.
  """

  alias Intellispark.Accounts.User
  alias Intellispark.Flags.Flag
  alias Intellispark.Recognition.HighFive
  alias Intellispark.Support.{Action, Note}
  alias Intellispark.Teams.TeamMembership

  require Ash.Query

  defmodule Digest do
    @moduledoc false
    defstruct [:user, :school_id, :week_starts_on, sections: []]
  end

  @spec build(User.t(), String.t(), Date.t()) :: Digest.t()
  def build(%User{} = user, school_id, week_starts_on) do
    student_ids = team_student_ids(user.id, school_id)
    high_fives = recent_high_fives(student_ids, school_id, week_starts_on)
    flags = recent_flags(student_ids, school_id, week_starts_on, user.id)
    actions = pending_actions_for(user.id, school_id)
    notes = recent_notes(student_ids, school_id, week_starts_on)

    sections =
      [
        {:high_fives, high_fives},
        {:flags, flags},
        {:actions_needed, actions},
        {:notes, notes}
      ]
      |> Enum.reject(fn {_, items} -> items == [] end)

    %Digest{
      user: user,
      school_id: school_id,
      week_starts_on: week_starts_on,
      sections: sections
    }
  end

  @spec empty?(Digest.t()) :: boolean()
  def empty?(%Digest{sections: []}), do: true
  def empty?(_), do: false

  defp team_student_ids(user_id, school_id) do
    TeamMembership
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.student_id)
    |> Enum.uniq()
  end

  defp recent_high_fives([], _, _), do: []

  defp recent_high_fives(student_ids, school_id, since) do
    since_dt = DateTime.new!(since, ~T[00:00:00])

    HighFive
    |> Ash.Query.filter(student_id in ^student_ids and sent_at >= ^since_dt)
    |> Ash.Query.load([:student, :sent_by])
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read!(authorize?: false)
  end

  defp recent_flags([], _, _, _), do: []

  defp recent_flags(student_ids, school_id, since, recipient_user_id) do
    since_dt = DateTime.new!(since, ~T[00:00:00])

    Flag
    |> Ash.Query.filter(
      student_id in ^student_ids and
        inserted_at >= ^since_dt and
        status not in [:closed, :draft]
    )
    |> Ash.Query.load([:student, :flag_type, assignments: [:user]])
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&annotate_assignment(&1, recipient_user_id))
  end

  defp annotate_assignment(flag, recipient_id) do
    assigned? =
      flag
      |> Map.get(:assignments, [])
      |> List.wrap()
      |> Enum.any?(&(is_nil(&1.cleared_at) and &1.user_id == recipient_id))

    Map.put(flag, :assigned_to_recipient?, assigned?)
  end

  defp pending_actions_for(user_id, school_id) do
    week_from_now = Date.utc_today() |> Date.add(7)

    Action
    |> Ash.Query.filter(
      assignee_id == ^user_id and
        status == :pending and
        (is_nil(due_on) or due_on <= ^week_from_now)
    )
    |> Ash.Query.load([:student])
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read!(authorize?: false)
  end

  defp recent_notes([], _, _), do: []

  defp recent_notes(student_ids, school_id, since) do
    since_dt = DateTime.new!(since, ~T[00:00:00])

    Note
    |> Ash.Query.filter(
      student_id in ^student_ids and
        inserted_at >= ^since_dt and
        sensitive? == false
    )
    |> Ash.Query.load([:student, :author])
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read!(authorize?: false)
  end
end
