defmodule Intellispark.Students.StudentStatus do
  @moduledoc """
  Ledger of status assignments. The row with `cleared_at == nil` is the
  active status; closing it out and inserting a new row records the
  transition. Paper-trailed for FERPA audit.
  """

  use Intellispark.Resource, domain: Intellispark.Students

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "student_statuses"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :set_at, :utc_datetime_usec, allow_nil?: false, default: &DateTime.utc_now/0
    attribute :cleared_at, :utc_datetime_usec
    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :status, Intellispark.Students.Status, allow_nil?: false
    belongs_to :set_by, Intellispark.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :status_id]
      change relate_actor(:set_by)
    end

    update :clear do
      accept []
      change set_attribute(:cleared_at, &DateTime.utc_now/0)
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
