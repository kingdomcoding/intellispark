defmodule Intellispark.Students.Status do
  @moduledoc """
  An ordered, per-school student status (e.g. 'Active', 'Watch', 'Withdrawn').
  A student has at most one active status at a time via StudentStatus.
  """

  use Intellispark.Resource, domain: Intellispark.Students

  admin do
    label_field :name
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "statuses"
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
    attribute :color, :string, allow_nil?: false, default: "#4b4b4d", public?: true
    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    timestamps()
  end

  identities do
    identity :unique_name_per_school, [:school_id, :name]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    has_many :student_statuses, Intellispark.Students.StudentStatus
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :color, :position]
    end

    update :update do
      primary? true
      accept [:name, :color, :position]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
