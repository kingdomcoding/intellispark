defmodule Intellispark.Support.Note do
  @moduledoc """
  Plain-text case note authored by staff on a student record. Pin/unpin
  as separate actions. Paper-trailed so every edit has an audit trail;
  sensitive? gated by the same clinical-roles FilterCheck as sensitive
  Flags.
  """

  use Intellispark.Resource, domain: Intellispark.Support

  admin do
    label_field :preview
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["notes:student", :student_id]
    publish_all :update, ["notes:student", :student_id]
    publish_all :destroy, ["notes:student", :student_id]
  end

  postgres do
    table "notes"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string, allow_nil?: false, public?: true
    attribute :sensitive?, :boolean, allow_nil?: false, default: false, public?: true
    attribute :pinned?, :boolean, allow_nil?: false, default: false, public?: true
    attribute :pinned_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  calculations do
    calculate :preview,
              :string,
              expr(fragment("left(?, 80)", body))

    calculate :edited?,
              :boolean,
              expr(fragment("? > ? + interval '2 seconds'", updated_at, inserted_at))
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :author, Intellispark.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :body, :sensitive?]

      change Intellispark.Support.Changes.StampAuthor
    end

    update :update do
      primary? true
      accept [:body, :sensitive?]
      require_atomic? false
    end

    update :pin do
      accept []
      require_atomic? false
      change set_attribute(:pinned?, true)
      change set_attribute(:pinned_at, &DateTime.utc_now/0)
    end

    update :unpin do
      accept []
      require_atomic? false
      change set_attribute(:pinned?, false)
      change set_attribute(:pinned_at, nil)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffReadsNotesForStudent
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action([:update, :pin, :unpin]) do
      authorize_if IntellisparkWeb.Policies.AuthorOrAdminForNote
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
