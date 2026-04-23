defmodule Intellispark.Integrations.Transformers.CsvTest do
  use ExUnit.Case, async: true

  alias Intellispark.Integrations.Transformers.Csv

  test "parses OneRoster 1.2 header + 3 rows" do
    csv = """
    sourcedId,givenName,familyName,email,grades,status,gender,phone
    S001,Ada,Lovelace,ada@ex.com,9,active,F,555-0001
    S002,Alan,Turing,alan@ex.com,10,active,M,555-0002
    S003,Grace,Hopper,grace@ex.com,11,inactive,F,
    """

    provider = %{school_id: "abc-school-id"}

    assert {:ok, payloads} = Csv.transform_students(csv, provider)
    assert length(payloads) == 3

    [first | _] = payloads
    assert first.external_id == "S001"
    assert first.first_name == "Ada"
    assert first.last_name == "Lovelace"
    assert first.grade_level == 9
    assert first.enrollment_status == :active
    assert first.gender == :female
    assert first.school_id == "abc-school-id"
  end

  test "missing optional fields default gracefully" do
    csv = """
    sourcedId,givenName,familyName
    S100,Bob,Smith
    """

    assert {:ok, [payload]} =
             Csv.transform_students(csv, %{school_id: "s"})

    assert payload.gender == nil
    assert payload.enrollment_status == :active
    assert payload.grade_level == nil
  end

  test "empty input returns empty list" do
    assert {:ok, []} = Csv.transform_students("", %{school_id: "s"})
  end
end
