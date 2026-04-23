defmodule Intellispark.Support.InterventionLibraryItem do
  @moduledoc """
  Per-school configurable intervention library. School admins seed the
  list of accepted interventions (MTSS tier 1/2/3). Selecting one on
  the Student Hub creates a Support via `:create_from_intervention`.
  """

  use Intellispark.Resource, domain: Intellispark.Support

  admin do
    label_field :title
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["intervention_library_items:school", :school_id]
    publish_all :update, ["intervention_library_items:school", :school_id]
    publish_all :destroy, ["intervention_library_items:school", :school_id]
  end

  postgres do
    table "intervention_library_items"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true

    attribute :mtss_tier, :atom do
      allow_nil? false
      constraints one_of: [:tier_1, :tier_2, :tier_3]
      public? true
    end

    attribute :default_duration_days, :integer, default: 30, public?: true
    attribute :active?, :boolean, default: true, public?: true

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    has_many :supports, Intellispark.Support.Support,
      destination_attribute: :intervention_library_item_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :description, :mtss_tier, :default_duration_days, :active?]
    end

    update :update do
      primary? true
      accept [:title, :description, :mtss_tier, :default_duration_days, :active?]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}
    end
  end
end
