defmodule Intellispark.FlagsFixtures do
  @moduledoc """
  Test fixtures for Phase 4 Flag resources. Adds flag types, flags, and
  flag assignments on top of the Phase 2 StudentsFixtures.setup_world/0.
  """

  alias Intellispark.Flags
  alias Intellispark.Flags.{FlagAssignment, FlagType}

  def create_flag_type!(school, attrs \\ %{}) do
    defaults = %{
      name: "Type#{System.unique_integer([:positive])}",
      color: "#2B4366",
      default_sensitive?: false
    }

    Ash.create!(FlagType, Map.merge(defaults, attrs), tenant: school.id, authorize?: false)
  end

  def create_flag!(actor, school, student, type, attrs \\ %{}) do
    description = Map.get(attrs, :description, "test flag #{System.unique_integer([:positive])}")

    {:ok, flag} =
      Flags.create_flag(student.id, type.id, description,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    Ash.load!(flag, [:assignments, assignments: [:user]],
      tenant: school.id,
      authorize?: false
    )
  end

  def open_flag!(flag, assignee_ids, actor) do
    {:ok, opened} =
      Flags.open_flag(flag, assignee_ids,
        actor: actor,
        tenant: flag.school_id,
        authorize?: false
      )

    opened
  end

  def close_flag!(flag, note, actor) do
    {:ok, closed} =
      Flags.close_flag(flag, note, actor: actor, tenant: flag.school_id, authorize?: false)

    closed
  end

  def set_followup!(flag, date, actor) do
    {:ok, updated} =
      Flags.set_flag_followup(flag, date,
        actor: actor,
        tenant: flag.school_id,
        authorize?: false
      )

    updated
  end

  def active_assignments(school, flag_id) do
    require Ash.Query

    FlagAssignment
    |> Ash.Query.filter(flag_id == ^flag_id and is_nil(cleared_at))
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read!(authorize?: false)
  end
end
