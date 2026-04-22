defmodule IntellisparkWeb.InsightsController do
  @moduledoc """
  CSV export endpoint for the Phase 9 Insights view. Responds to
  `GET /insights/export.csv` with a NimbleCSV-formatted attachment
  containing `Student, Dimension, Level` per row.
  """

  use IntellisparkWeb, :controller

  alias Intellispark.Indicators
  alias Intellispark.Indicators.Dimension

  def export(conn, params) do
    %{current_user: actor, current_school: school} = conn.assigns

    dim = resolve_dimension(params["dimension"])
    ids = resolve_student_ids(params, actor, school)

    rows = Indicators.individual_for(ids, dim, school.id)

    csv_iodata = build_csv(rows, dim)
    filename = "insights-#{Atom.to_string(dim)}-#{Date.utc_today()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv_iodata)
  end

  defp build_csv(rows, dim) do
    header = ["Student", "Dimension", "Level"]

    data =
      Enum.map(rows, fn row ->
        [
          row.name || "",
          Dimension.humanize(dim),
          if(row.level, do: Atom.to_string(row.level), else: "not measured")
        ]
      end)

    NimbleCSV.RFC4180.dump_to_iodata([header | data])
  end

  defp resolve_dimension(nil), do: hd(Dimension.all())

  defp resolve_dimension(str) when is_binary(str) do
    case Dimension.from_string(str) do
      {:ok, dim} -> dim
      :error -> hd(Dimension.all())
    end
  end

  defp resolve_student_ids(%{"student_ids" => csv}, _actor, _school) when is_binary(csv) do
    csv |> String.split(",") |> Enum.reject(&(&1 == ""))
  end

  defp resolve_student_ids(%{"list_id" => list_id}, actor, school) do
    case Intellispark.Students.run_custom_list(list_id, actor: actor, tenant: school.id) do
      {:ok, students} -> Enum.map(students, & &1.id)
      _ -> []
    end
  end

  defp resolve_student_ids(_params, _actor, school) do
    Intellispark.Students.Student
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end
end
