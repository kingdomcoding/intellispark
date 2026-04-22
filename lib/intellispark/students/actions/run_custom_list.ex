defmodule Intellispark.Students.Actions.RunCustomList do
  @moduledoc """
  Generic read action that loads a CustomList, applies each of its
  FilterSpec predicates to the Student read path, and returns the
  matching rows under the current tenant.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Intellispark.Students.{CustomList, Student}

  @impl true
  def run(input, _opts, context) do
    id = input.arguments.custom_list_id
    tenant = context.tenant
    actor = context.actor

    with {:ok, list} <-
           Ash.get(CustomList, id, tenant: tenant, actor: actor, authorize?: true) do
      students =
        Student
        |> Ash.Query.set_tenant(tenant)
        |> apply_filters(list.filters || %Intellispark.Students.FilterSpec{})
        |> Ash.Query.sort([:last_name, :first_name])
        |> Ash.read!(actor: actor, authorize?: true)

      {:ok, students}
    end
  end

  defp apply_filters(query, spec) do
    query
    |> apply_tag_ids(spec.tag_ids)
    |> apply_status_ids(spec.status_ids)
    |> apply_grade_levels(spec.grade_levels)
    |> apply_enrollment_statuses(spec.enrollment_statuses)
    |> apply_name_contains(spec.name_contains)
    |> apply_no_high_five_in_30_days(Map.get(spec, :no_high_five_in_30_days, false))
    |> apply_has_open_survey_assignment(Map.get(spec, :has_open_survey_assignment, false))
    |> apply_dimension_filters(spec)
  end

  defp apply_tag_ids(query, []), do: query

  defp apply_tag_ids(query, ids) do
    Ash.Query.filter(query, exists(student_tags, tag_id in ^ids))
  end

  defp apply_status_ids(query, []), do: query

  defp apply_status_ids(query, ids) do
    Ash.Query.filter(query, current_status_id in ^ids)
  end

  defp apply_grade_levels(query, []), do: query

  defp apply_grade_levels(query, levels) do
    Ash.Query.filter(query, grade_level in ^levels)
  end

  defp apply_enrollment_statuses(query, []), do: query

  defp apply_enrollment_statuses(query, list) do
    Ash.Query.filter(query, enrollment_status in ^list)
  end

  defp apply_name_contains(query, nil), do: query
  defp apply_name_contains(query, ""), do: query

  defp apply_name_contains(query, term) do
    like = "%#{term}%"

    Ash.Query.filter(
      query,
      ilike(first_name, ^like) or ilike(last_name, ^like) or ilike(preferred_name, ^like)
    )
  end

  defp apply_no_high_five_in_30_days(query, true) do
    query
    |> Ash.Query.load(:recent_high_fives_count)
    |> Ash.Query.filter(recent_high_fives_count == 0)
  end

  defp apply_no_high_five_in_30_days(query, _), do: query

  defp apply_has_open_survey_assignment(query, true) do
    query
    |> Ash.Query.load(:open_survey_assignments_count)
    |> Ash.Query.filter(open_survey_assignments_count > 0)
  end

  defp apply_has_open_survey_assignment(query, _), do: query

  defp apply_dimension_filters(query, spec) do
    Enum.reduce(Intellispark.Indicators.Dimension.all(), query, fn dim, q ->
      case Map.get(spec, dim) do
        nil ->
          q

        level when level in [:low, :moderate, :high] ->
          Ash.Query.filter(
            q,
            exists(indicator_scores, dimension == ^dim and level == ^level)
          )
      end
    end)
  end
end
