defmodule Intellispark.Flags.Flag do
  @moduledoc """
  Student incident / concern record. State machine (Phase F): draft → open
  → assigned → under_review → pending_followup → closed (→ reopened).
  Every transition is a paper-trailed Ash action; invalid transitions
  raise at the resource layer. Hourly AshOban trigger auto-closes flags
  past their auto_close_at.
  """

  use Intellispark.Resource, domain: Intellispark.Flags

  admin do
    label_field :short_description
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :status]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    publish_all :create, ["flags:school", :school_id]
    publish_all :update, ["flags:school", :school_id]
    publish_all :create, ["flags:student", :student_id]
    publish_all :update, ["flags:student", :student_id]
    publish_all :destroy, ["flags:school", :school_id]
    publish_all :destroy, ["flags:student", :student_id]
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
