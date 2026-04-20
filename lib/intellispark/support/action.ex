defmodule Intellispark.Support.Action do
  @moduledoc """
  A follow-up task assigned to a staff member about a student. Binary
  completion via checkbox; cancelled state exists for audit when an
  action was raised in error. State machine: :pending -> :completed /
  :cancelled (both terminal).
  """

  use Intellispark.Resource,
    domain: Intellispark.Support,
    extensions: [AshStateMachine]

  admin do
    label_field :description
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :status]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["actions:school", :school_id]
    publish_all :update, ["actions:school", :school_id]
    publish_all :create, ["actions:student", :student_id]
    publish_all :update, ["actions:student", :student_id]
    publish_all :destroy, ["actions:school", :school_id]
    publish_all :destroy, ["actions:student", :student_id]
  end

  state_machine do
    state_attribute :status
    initial_states [:pending]
    default_initial_state :pending

    transitions do
      transition :complete, from: :pending, to: :completed
      transition :cancel, from: :pending, to: :cancelled
    end
  end

  postgres do
    table "actions"
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
    attribute :due_on, :date, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true
    attribute :cancellation_reason, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :completed, :cancelled]
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :assignee, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :opened_by, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :completed_by, Intellispark.Accounts.User
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :assignee_id, :description, :due_on]

      change Intellispark.Support.Changes.StampOpenedBy
    end

    update :update do
      primary? true
      accept [:description, :due_on, :assignee_id]
      require_atomic? false
    end

    update :complete do
      accept []
      require_atomic? false

      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change Intellispark.Support.Changes.StampCompletedBy
      change transition_state(:completed)
    end

    update :cancel do
      argument :reason, :string
      accept []
      require_atomic? false

      change set_attribute(:cancellation_reason, arg(:reason))
      change transition_state(:cancelled)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action([:update, :cancel]) do
      authorize_if IntellisparkWeb.Policies.AssigneeOrOpenerOrAdminForAction
    end

    policy action(:complete) do
      authorize_if IntellisparkWeb.Policies.AssigneeOrAdminForAction
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
