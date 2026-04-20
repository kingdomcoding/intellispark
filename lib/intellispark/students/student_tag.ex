defmodule Intellispark.Students.StudentTag do
  @moduledoc """
  Join row between Student and Tag. Carries applied_at and applied_by so we
  can answer 'who tagged this student and when'. Paper-trailed.
  """

  use Intellispark.Resource, domain: Intellispark.Students

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "student_tags"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :applied_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :tag, Intellispark.Students.Tag, allow_nil?: false
    belongs_to :applied_by, Intellispark.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_student_tag, [:student_id, :tag_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :tag_id]
      change relate_actor(:applied_by)
    end
  end

  policies do
    policy action_type([:read, :create, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
