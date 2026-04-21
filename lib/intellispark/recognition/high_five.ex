defmodule Intellispark.Recognition.HighFive do
  @moduledoc """
  A sent High 5. Denormalises title + body from the template so template
  edits don't retroactively rewrite history. Carries a 128-bit random
  token used for the unauthenticated public view at
  `/high-fives/:token`.
  """

  use Intellispark.Resource,
    domain: Intellispark.Recognition,
    notifiers: [Intellispark.Recognition.Notifiers.Emails]

  admin do
    label_field :title
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["high_fives:school", :school_id]
    publish_all :create, ["high_fives:student", :student_id]
    publish_all :update, ["high_fives:student", :student_id]
    publish_all :destroy, ["high_fives:school", :school_id]
    publish_all :destroy, ["high_fives:student", :student_id]
  end

  postgres do
    table "high_fives"
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
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :recipient_email, :string, allow_nil?: false, public?: true

    attribute :token, :string do
      allow_nil? false
      public? false
    end

    attribute :sent_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0

    attribute :first_viewed_at, :utc_datetime_usec, public?: true

    attribute :view_count, :integer,
      allow_nil?: false,
      default: 0,
      public?: true

    timestamps()
  end

  identities do
    identity :unique_token, [:token]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :sent_by, Intellispark.Accounts.User, allow_nil?: false

    belongs_to :template, Intellispark.Recognition.HighFiveTemplate,
      attribute_writable?: true,
      public?: true

    has_many :views, Intellispark.Recognition.HighFiveView
  end

  aggregates do
    count :view_audit_count, :views
  end

  actions do
    defaults [:read, :destroy]

    create :send_to_student do
      accept [:student_id, :title, :body, :recipient_email, :template_id]

      change Intellispark.Recognition.Changes.StampSender
      change Intellispark.Recognition.Changes.GenerateToken
      change Intellispark.Recognition.Changes.ResolveRecipientEmail
    end

    # Read-by-token for the public view. Does not set_tenant — the
    # token IS the auth so we bypass multitenancy via the per-action
    # override below.
    read :by_token do
      argument :token, :string, allow_nil?: false
      filter expr(token == ^arg(:token))
      multitenancy :bypass
    end

    update :record_view do
      accept []
      argument :user_agent, :string, allow_nil?: true
      argument :ip_hash, :string, allow_nil?: true
      require_atomic? false

      change set_attribute(
               :first_viewed_at,
               expr(
                 if is_nil(first_viewed_at) do
                   now()
                 else
                   first_viewed_at
                 end
               )
             )

      change Intellispark.Recognition.Changes.IncrementViewCount
      change Intellispark.Recognition.Changes.LogView
    end

    action :bulk_send_to_students, :struct do
      constraints instance_of: Ash.BulkResult

      argument :student_ids, {:array, :uuid}, allow_nil?: false
      argument :template_id, :uuid, allow_nil?: false

      run Intellispark.Recognition.Actions.BulkSendHighFives
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action(:by_token) do
      authorize_if always()
    end

    policy action(:record_view) do
      authorize_if always()
    end

    policy action(:send_to_student) do
      authorize_if IntellisparkWeb.Policies.CanSendHighFive
    end

    policy action(:bulk_send_to_students) do
      authorize_if IntellisparkWeb.Policies.CanSendHighFive
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
