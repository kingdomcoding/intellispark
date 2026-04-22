defmodule Intellispark.Flags.Flag do
  @moduledoc """
  Student incident / concern record. State machine (Phase F): draft → open
  → assigned → under_review → pending_followup → closed (→ reopened).
  Every transition is a paper-trailed Ash action; invalid transitions
  raise at the resource layer. Hourly AshOban trigger auto-closes flags
  past their auto_close_at.
  """

  use Intellispark.Resource,
    domain: Intellispark.Flags,
    extensions: [AshStateMachine],
    notifiers: [Intellispark.Flags.Notifiers.Emails]

  admin do
    label_field :short_description
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :status]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    # Reset the 'resource' prefix that Intellispark.Resource's default
    # pub_sub block sets — we want unprefixed topics so LiveView subs
    # like "flags:student:<id>" match the broadcast.
    prefix ""
    publish_all :create, ["flags:school", :school_id]
    publish_all :update, ["flags:school", :school_id]
    publish_all :create, ["flags:student", :student_id]
    publish_all :update, ["flags:student", :student_id]
    publish_all :destroy, ["flags:school", :school_id]
    publish_all :destroy, ["flags:student", :student_id]
  end

  state_machine do
    state_attribute :status
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :open_flag, from: [:draft, :reopened], to: :open
      transition :assign, from: [:open, :assigned, :under_review, :reopened], to: :assigned
      transition :move_to_review, from: [:open, :assigned, :reopened], to: :under_review

      transition :set_followup,
        from: [:open, :assigned, :under_review, :reopened],
        to: :pending_followup

      transition :close_with_resolution,
        from: [:open, :assigned, :under_review, :pending_followup, :reopened],
        to: :closed

      transition :auto_close,
        from: [:open, :assigned, :under_review, :pending_followup, :reopened],
        to: :closed

      transition :reopen, from: [:closed], to: :reopened
    end
  end

  postgres do
    table "flags"
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
    attribute :short_description, :string, public?: true
    attribute :sensitive?, :boolean, allow_nil?: false, default: false, public?: true
    attribute :resolution_note, :string, public?: true
    attribute :followup_at, :date, public?: true
    attribute :auto_close_at, :utc_datetime_usec, public?: true

    attribute :status, :atom do
      allow_nil? false
      default :draft

      constraints one_of: [
                    :draft,
                    :open,
                    :assigned,
                    :under_review,
                    :pending_followup,
                    :closed,
                    :reopened
                  ]

      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :flag_type, Intellispark.Flags.FlagType, allow_nil?: false
    belongs_to :opened_by, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :closed_by, Intellispark.Accounts.User

    has_many :assignments, Intellispark.Flags.FlagAssignment

    many_to_many :assignees, Intellispark.Accounts.User do
      through Intellispark.Flags.FlagAssignment
      source_attribute_on_join_resource :flag_id
      destination_attribute_on_join_resource :user_id
    end

    has_many :comments, Intellispark.Flags.FlagComment
  end

  aggregates do
    count :assignee_count, :assignments do
      filter expr(is_nil(cleared_at))
    end

    count :comment_count, :comments
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :flag_type_id, :description, :sensitive?, :followup_at, :auto_close_at]

      change Intellispark.Flags.Changes.StampOpenedBy
      change Intellispark.Flags.Changes.InheritSensitivityFromType
      change Intellispark.Flags.Changes.SetShortDescription
      change Intellispark.Flags.Changes.DefaultAutoCloseAt
    end

    update :open_flag do
      argument :assignee_ids, {:array, :uuid}, allow_nil?: false
      require_atomic? false

      change transition_state(:open)
      change Intellispark.Flags.Changes.SyncAssignments
    end

    update :assign do
      argument :assignee_ids, {:array, :uuid}, allow_nil?: false
      require_atomic? false

      change transition_state(:assigned)
      change Intellispark.Flags.Changes.SyncAssignments
    end

    update :move_to_review do
      require_atomic? false
      change transition_state(:under_review)
    end

    update :set_followup do
      argument :followup_at, :date, allow_nil?: false
      require_atomic? false

      change set_attribute(:followup_at, arg(:followup_at))
      change transition_state(:pending_followup)
    end

    update :close_with_resolution do
      argument :resolution_note, :string, allow_nil?: true, default: ""
      argument :followup_at, :date, allow_nil?: true, default: nil
      require_atomic? false

      change set_attribute(:resolution_note, arg(:resolution_note))
      change Intellispark.Flags.Changes.MaybeSetFollowup
      change Intellispark.Flags.Changes.StampClosedBy
      change transition_state(:closed)
    end

    update :auto_close do
      require_atomic? false
      change set_attribute(:resolution_note, "Auto-closed: no activity for 30 days.")
      change transition_state(:closed)
    end

    update :reopen do
      require_atomic? false
      change Intellispark.Flags.Changes.ClearResolution
      change transition_state(:reopened)
    end
  end

  oban do
    triggers do
      trigger :auto_close_stale_flags do
        action :auto_close
        queue :notifications
        scheduler_cron "0 * * * *"
        worker_module_name Intellispark.Flags.Flag.AshOban.Worker.AutoCloseStaleFlags
        scheduler_module_name Intellispark.Flags.Flag.AshOban.Scheduler.AutoCloseStaleFlags
        list_tenants &Intellispark.Flags.Flag.list_school_tenants/0

        where expr(
                auto_close_at <= now() and
                  status in [:open, :assigned, :under_review, :pending_followup]
              )
      end
    end
  end

  @doc false
  def list_school_tenants do
    Intellispark.Accounts.School
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffReadsFlagsForStudent
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action([:open_flag, :assign, :move_to_review, :set_followup]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action(:close_with_resolution) do
      authorize_if IntellisparkWeb.Policies.AssigneeOrClinicalActorForFlag
    end

    policy action(:auto_close) do
      authorize_if always()
    end

    policy action(:reopen) do
      authorize_if IntellisparkWeb.Policies.OpenerOrAdminForFlag
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
