defmodule Intellispark.Integrations.Transformers.Csv do
  @moduledoc """
  CSV transformer. Accepts a binary matching OneRoster 1.2's student
  CSV header (sourcedId, givenName, familyName, email, grades, status,
  gender, phone). Returns canonical payload maps for
  `Student.:upsert_from_sis`.
  """

  @behaviour Intellispark.Integrations.Transformer

  NimbleCSV.define(__MODULE__.Parser, separator: ",", escape: "\"")

  @impl true
  def transform_students(csv_binary, provider) when is_binary(csv_binary) do
    case rows(csv_binary) do
      [] ->
        {:ok, []}

      [header | data] ->
        payloads =
          Enum.map(data, fn values ->
            row = Enum.zip(header, values) |> Map.new()

            %{
              external_id: row["sourcedId"] || row["student_id"],
              first_name: row["givenName"] || row["first_name"],
              last_name: row["familyName"] || row["last_name"],
              email: row["email"],
              grade_level: parse_grade(row["grades"] || row["grade"]),
              enrollment_status: parse_enrollment(row["status"]),
              gender: parse_gender(row["gender"]),
              phone: row["phone"],
              school_id: provider.school_id
            }
          end)

        {:ok, payloads}
    end
  end

  def transform_students(_payload, _provider), do: {:ok, []}

  @impl true
  def transform_rosters(_payload, _provider), do: {:ok, []}

  defp rows(csv_binary) do
    csv_binary
    |> __MODULE__.Parser.parse_string(skip_headers: false)
  rescue
    _ -> []
  end

  defp parse_grade(nil), do: nil
  defp parse_grade(""), do: nil

  defp parse_grade(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_grade(_), do: nil

  defp parse_enrollment("active"), do: :active
  defp parse_enrollment("inactive"), do: :inactive
  defp parse_enrollment("withdrawn"), do: :withdrawn
  defp parse_enrollment(nil), do: :active
  defp parse_enrollment(_), do: :active

  defp parse_gender("M"), do: :male
  defp parse_gender("F"), do: :female
  defp parse_gender("NB"), do: :nonbinary
  defp parse_gender(nil), do: :unspecified
  defp parse_gender(""), do: :unspecified
  defp parse_gender(_), do: :unspecified
end
