defmodule Intellispark.Teams.Strength do
  @moduledoc """
  A student strength — one bulleted item per row. Ordered by
  `display_order`; new strengths append with max+1. Phase 12 adds the
  drag-reorder UI; Phase 10 ships CRUD + sorted render only.
  """

  use Intellispark.Resource, domain: Intellispark.Teams

  admin do
    label_field :description
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["strengths:student", :student_id]
    publish_all :update, ["strengths:student", :student_id]
    publish_all :destroy, ["strengths:student", :student_id]
  end

  postgres do
    table "strengths"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :description, :string, allow_nil?: false, public?: true
    attribute :display_order, :integer, allow_nil?: false, default: 0, public?: true

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :added_by, Intellispark.Accounts.User, allow_nil?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :description, :display_order]
      change Intellispark.Teams.Changes.StampAddedBy
      change Intellispark.Teams.Changes.DefaultDisplayOrder
    end

    update :update do
      primary? true
      accept [:description, :display_order]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type([:update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
