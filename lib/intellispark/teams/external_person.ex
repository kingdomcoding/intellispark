defmodule Intellispark.Teams.ExternalPerson do
  @moduledoc """
  A non-staff person attached to a Student as a key connection or team
  member: parents, guardians, siblings, coaches, community partners.
  Tenant-scoped to school_id, paper-trailed. Backs the Family /
  community drill-in flow on the New Team Member modal.
  """

  use Intellispark.Resource, domain: Intellispark.Teams

  admin do
    label_field :display_name
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["external_persons:school", :school_id]
    publish_all :update, ["external_persons:school", :school_id]
    publish_all :destroy, ["external_persons:school", :school_id]
  end

  postgres do
    table "external_persons"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :last_name, :string, allow_nil?: false, public?: true

    attribute :relationship_kind, :atom do
      allow_nil? false

      constraints one_of: [
                    :parent,
                    :guardian,
                    :sibling,
                    :coach,
                    :community_partner,
                    :other
                  ]

      public? true
    end

    attribute :email, :string, public?: true
    attribute :phone, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :added_by, Intellispark.Accounts.User, allow_nil?: true

    has_many :key_connections, Intellispark.Teams.KeyConnection do
      destination_attribute :connected_external_person_id
    end
  end

  calculations do
    calculate :display_name,
              :string,
              expr(fragment("? || ' ' || ?", first_name, last_name))
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:first_name, :last_name, :relationship_kind, :email, :phone]
      change Intellispark.Teams.Changes.StampAddedBy
    end

    update :update do
      primary? true
      accept [:first_name, :last_name, :relationship_kind, :email, :phone]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.CounselorOrAdminForStudent
    end
  end
end
