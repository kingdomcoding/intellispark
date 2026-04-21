defmodule Intellispark.Assessments.SurveyAssignment do
  @moduledoc """
  A survey issued to a specific student. Carries a 128-bit access
  token used for the unauthenticated student-facing page at
  `/surveys/:token`. Pins to the `SurveyTemplateVersion` that was
  current at assign time so in-flight assignments survive template
  edits.
  """

  use Intellispark.Resource,
    domain: Intellispark.Assessments,
    extensions: [AshStateMachine],
    notifiers: [Intellispark.Assessments.Notifiers.Emails]

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :state]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["survey_assignments:school", :school_id]
    publish_all :create, ["survey_assignments:student", :student_id]
    publish_all :update, ["survey_assignments:student", :student_id]
    publish_all :destroy, ["survey_assignments:school", :school_id]
    publish_all :destroy, ["survey_assignments:student", :student_id]
  end

  state_machine do
    state_attribute :state
    initial_states [:assigned]
    default_initial_state :assigned

    transitions do
      transition :save_progress, from: :assigned, to: :in_progress
      transition :save_progress, from: :in_progress, to: :in_progress
      transition :submit, from: [:assigned, :in_progress], to: :submitted
      transition :expire, from: [:assigned, :in_progress], to: :expired
    end
  end

  postgres do
    table "survey_assignments"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :state, :atom do
      allow_nil? false
      default :assigned
      constraints one_of: [:assigned, :in_progress, :submitted, :expired]
      public? true
    end

    attribute :token, :string do
      allow_nil? false
      public? false
    end

    attribute :assigned_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0

    attribute :first_opened_at, :utc_datetime_usec, public?: true
    attribute :submitted_at, :utc_datetime_usec, public?: true
    attribute :expires_at, :utc_datetime_usec, public?: true
    attribute :last_reminded_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  identities do
    identity :unique_token, [:token]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :assigned_by, Intellispark.Accounts.User, allow_nil?: false

    belongs_to :survey_template, Intellispark.Assessments.SurveyTemplate,
      allow_nil?: false

    belongs_to :survey_template_version,
               Intellispark.Assessments.SurveyTemplateVersion,
               allow_nil?: false

    has_many :responses, Intellispark.Assessments.SurveyResponse,
      destination_attribute: :survey_assignment_id
  end

  actions do
    defaults [:read, :destroy]

    create :assign_to_student do
      accept [:student_id, :survey_template_id]

      change Intellispark.Assessments.Changes.StampAssignedBy
      change Intellispark.Assessments.Changes.GenerateAccessToken
      change Intellispark.Assessments.Changes.PinTemplateVersion
      change Intellispark.Assessments.Changes.DefaultExpiresAt
    end

    action :bulk_assign_to_students, :struct do
      constraints instance_of: Ash.BulkResult

      argument :student_ids, {:array, :uuid}, allow_nil?: false
      argument :survey_template_id, :uuid, allow_nil?: false

      argument :mode, :atom do
        allow_nil? false
        default :skip_previously_submitted
        constraints one_of: [:skip_previously_submitted, :assign_regardless]
      end

      run Intellispark.Assessments.Actions.BulkAssignSurvey
    end

    read :by_token do
      argument :token, :string, allow_nil?: false
      filter expr(token == ^arg(:token))
      multitenancy :bypass
    end

    update :save_progress do
      require_atomic? false

      argument :question_id, :uuid, allow_nil?: false
      argument :answer_text, :string, allow_nil?: true
      argument :answer_values, {:array, :string}, allow_nil?: true

      change Intellispark.Assessments.Changes.MarkInProgress
      change Intellispark.Assessments.Changes.UpsertResponse
    end

    update :submit do
      accept []
      require_atomic? false

      change Intellispark.Assessments.Changes.ValidateRequiredResponses
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
      change transition_state(:submitted)
    end

    update :expire do
      accept []
      require_atomic? false
      change transition_state(:expired)
    end

    update :touch_last_reminded do
      accept []
      require_atomic? false
      change set_attribute(:last_reminded_at, &DateTime.utc_now/0)
    end
  end

  oban do
    triggers do
      trigger :expire_stale_assignments do
        action :expire
        queue :notifications
        scheduler_cron "0 * * * *"

        worker_module_name(
          Intellispark.Assessments.SurveyAssignment.AshOban.Worker.ExpireStaleAssignments
        )

        scheduler_module_name(
          Intellispark.Assessments.SurveyAssignment.AshOban.Scheduler.ExpireStaleAssignments
        )

        list_tenants &Intellispark.Assessments.SurveyAssignment.list_school_tenants/0

        where expr(
                expires_at <= now() and state in [:assigned, :in_progress]
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
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action(:by_token) do
      authorize_if always()
    end

    policy action([:save_progress, :submit]) do
      authorize_if always()
    end

    policy action([:assign_to_student, :bulk_assign_to_students]) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action(:expire) do
      authorize_if always()
    end

    policy action(:touch_last_reminded) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
