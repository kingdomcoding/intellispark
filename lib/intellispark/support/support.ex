defmodule Intellispark.Support.Support do
  @moduledoc """
  An intervention plan — "Flex Time Pass", "Mental Health Services".
  Four-state lifecycle: :offered -> :in_progress -> :completed, or
  :offered -> :declined. Optional date range. Provider is a single staff
  member (multi-provider deferred to Phase 10 Teams).
  """

  use Intellispark.Resource,
    domain: Intellispark.Support,
    extensions: [AshStateMachine]

  admin do
    label_field :title
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :status]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["supports:school", :school_id]
    publish_all :update, ["supports:school", :school_id]
    publish_all :create, ["supports:student", :student_id]
    publish_all :update, ["supports:student", :student_id]
    publish_all :destroy, ["supports:school", :school_id]
    publish_all :destroy, ["supports:student", :student_id]
  end

  state_machine do
    state_attribute :status
    initial_states [:offered]
    default_initial_state :offered

    transitions do
      transition :accept, from: :offered, to: :in_progress
      transition :decline, from: :offered, to: :declined
      transition :complete, from: :in_progress, to: :completed
    end
  end

  postgres do
    table "supports"
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
    attribute :starts_at, :date, public?: true
    attribute :ends_at, :date, public?: true
    attribute :decline_reason, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      default :offered
      constraints one_of: [:offered, :in_progress, :completed, :declined]
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :offered_by, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :provider_staff, Intellispark.Accounts.User

    belongs_to :intervention_library_item,
               Intellispark.Support.InterventionLibraryItem,
               allow_nil?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :title, :description, :starts_at, :ends_at, :provider_staff_id]

      change Intellispark.Support.Changes.StampOfferedBy
    end

    update :update do
      primary? true

      accept [
        :title,
        :description,
        :starts_at,
        :ends_at,
        :provider_staff_id
      ]

      require_atomic? false
    end

    update :accept do
      accept []
      require_atomic? false
      change transition_state(:in_progress)
    end

    update :decline do
      argument :reason, :string
      accept []
      require_atomic? false

      change set_attribute(:decline_reason, arg(:reason))
      change transition_state(:declined)
    end

    update :complete do
      accept []
      require_atomic? false
      change transition_state(:completed)
    end

    create :create_from_intervention do
      argument :intervention_library_item_id, :uuid, allow_nil?: false

      accept [
        :student_id,
        :title,
        :description,
        :starts_at,
        :ends_at,
        :provider_staff_id
      ]

      change Intellispark.Support.Changes.StampOfferedBy
      change Intellispark.Support.Changes.PrefillFromIntervention
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action(:create_from_intervention) do
      authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}
    end

    policy action([:accept, :decline, :complete, :update]) do
      authorize_if IntellisparkWeb.Policies.ProviderOrClinicalActorForSupport
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
