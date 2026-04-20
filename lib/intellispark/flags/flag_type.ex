defmodule Intellispark.Flags.FlagType do
  @moduledoc """
  Per-school flag category ("Academic", "Attendance", "Mental health", etc.).
  Tenant-scoped on school_id. Seeded with a default set; admins add more
  through AshAdmin.
  """

  use Intellispark.Resource, domain: Intellispark.Flags

  admin do
    label_field :name
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "flag_types"
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
    attribute :color, :string, allow_nil?: false, default: "#A1452E", public?: true
    attribute :default_sensitive?, :boolean, allow_nil?: false, default: false, public?: true
    timestamps()
  end

  identities do
    identity :unique_name_per_school, [:school_id, :name]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    has_many :flags, Intellispark.Flags.Flag
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :color, :default_sensitive?]
    end

    update :update do
      primary? true
      accept [:name, :color, :default_sensitive?]
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
