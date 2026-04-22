defmodule Intellispark.Indicators.DimensionTest do
  use ExUnit.Case, async: true

  alias Intellispark.Indicators.Dimension

  describe "all/0" do
    test "returns exactly 13 dimensions in canonical display order" do
      dims = Dimension.all()

      assert length(dims) == 13

      assert dims == [
               :belonging,
               :connection,
               :decision_making,
               :engagement,
               :readiness,
               :relationship_skills,
               :relationships_adult,
               :relationships_networks,
               :relationships_peer,
               :self_awareness,
               :self_management,
               :social_awareness,
               :well_being
             ]
    end
  end

  describe "humanize/1" do
    test "round-trips for every atom in all/0" do
      for dim <- Dimension.all() do
        assert is_binary(Dimension.humanize(dim))
      end
    end

    test "handles special cases verbatim" do
      assert Dimension.humanize(:well_being) == "Well-Being"
      assert Dimension.humanize(:relationships_adult) == "Relationships (Adult)"
      assert Dimension.humanize(:relationships_networks) == "Relationships (Networks)"
      assert Dimension.humanize(:relationships_peer) == "Relationships (Peer)"
    end
  end

  describe "from_string/1" do
    test "returns :ok tuple for valid names" do
      assert Dimension.from_string("belonging") == {:ok, :belonging}
      assert Dimension.from_string("well_being") == {:ok, :well_being}
    end

    test "returns :error for unknown strings" do
      assert Dimension.from_string("bogus") == :error
      assert Dimension.from_string("") == :error
      assert Dimension.from_string("BELONGING") == :error
    end
  end
end
