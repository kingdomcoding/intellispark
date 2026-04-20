defmodule Intellispark.Students.Tag do
  @moduledoc """
  Per-school freeform categorization. A student can have many tags;
  a tag can be applied to many students via the StudentTag join.
  """

  use Intellispark.Resource, domain: Intellispark.Students

  admin do
    label_field :name
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "tags"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :color, :string, allow_nil?: false, default: "#2b4366", public?: true
    attribute :description, :string, public?: true
    timestamps()
  end

  identities do
    identity :unique_name_per_school, [:school_id, :name]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    has_many :student_tags, Intellispark.Students.StudentTag
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :color, :description]
    end

    update :update do
      primary? true
      accept [:name, :color, :description]
      require_atomic? false
    end
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
