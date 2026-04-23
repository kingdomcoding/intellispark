defmodule Intellispark.Teams.KeyConnection do
  @moduledoc """
  A meaningful relationship between a Student and a staff User, often
  self-reported by the student on a survey. `note` carries the display
  provenance string ("self-reported on Insightfull Sep 14, 2020" /
  "added by Curtis Murphy on …"). Phase 14 will generalise
  connected_user_id into a polymorphic connected-person reference for
  family + community contacts.
  """

  use Intellispark.Resource, domain: Intellispark.Teams

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [
      :school_id,
      :student_id,
      :connected_user_id,
      :connected_external_person_id
    ]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["key_connections:student", :student_id]
    publish_all :update, ["key_connections:student", :student_id]
    publish_all :destroy, ["key_connections:student", :student_id]
  end

  postgres do
    table "key_connections"
    repo Intellispark.Repo

    identity_wheres_to_sql unique_per_student_user: "connected_user_id IS NOT NULL",
                           unique_per_student_external_person:
                             "connected_external_person_id IS NOT NULL"
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :note, :string, public?: true

    attribute :source, :atom do
      allow_nil? false
      default :added_manually
      constraints one_of: [:self_reported, :added_manually]
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_per_student_user, [:student_id, :connected_user_id],
      where: expr(not is_nil(connected_user_id))

    identity :unique_per_student_external_person,
             [:student_id, :connected_external_person_id],
             where: expr(not is_nil(connected_external_person_id))
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :connected_user, Intellispark.Accounts.User, allow_nil?: true

    belongs_to :connected_external_person, Intellispark.Teams.ExternalPerson, allow_nil?: true

    belongs_to :added_by, Intellispark.Accounts.User, allow_nil?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :connected_user_id, :note, :source]
      change Intellispark.Teams.Changes.StampAddedBy
      change Intellispark.Teams.Changes.ValidateConnectedTarget
    end

    create :create_for_external_person do
      accept [:student_id, :connected_external_person_id, :note, :source]
      change Intellispark.Teams.Changes.StampAddedBy
      change Intellispark.Teams.Changes.ValidateConnectedTarget
    end

    update :update do
      primary? true
      accept [:note]
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
