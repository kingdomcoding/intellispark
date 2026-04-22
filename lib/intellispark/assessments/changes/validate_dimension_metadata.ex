defmodule Intellispark.Assessments.Changes.ValidateDimensionMetadata do
  @moduledoc false
  use Ash.Resource.Change

  alias Intellispark.Indicators.Dimension

  @impl true
  def change(changeset, _opts, _context) do
    qtype = Ash.Changeset.get_attribute(changeset, :question_type)
    meta = Ash.Changeset.get_attribute(changeset, :metadata) || %{}

    case qtype do
      :dimension_rating ->
        case Dimension.from_string(meta["dimension"] || "") do
          {:ok, _} ->
            changeset

          :error ->
            Ash.Changeset.add_error(changeset,
              field: :metadata,
              message:
                "dimension_rating requires metadata.dimension to be one of the 13 canonical dimensions"
            )
        end

      _ ->
        changeset
    end
  end
end
