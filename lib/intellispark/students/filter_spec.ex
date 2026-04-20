defmodule Intellispark.Students.FilterSpec do
  @moduledoc """
  Typed filter schema stored inside CustomList.filters. Serialises as a
  jsonb column but validates its shape on write via the embedded Ash
  resource. Adding a new filter dimension = adding an attribute here +
  wiring it in RunCustomList.
  """

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :tag_ids, {:array, :uuid}, default: [], public?: true
    attribute :status_ids, {:array, :uuid}, default: [], public?: true
    attribute :grade_levels, {:array, :integer}, default: [], public?: true

    attribute :enrollment_statuses, {:array, :atom} do
      constraints items: [one_of: [:active, :inactive, :graduated, :withdrawn]]
      default []
      public? true
    end

    attribute :name_contains, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
