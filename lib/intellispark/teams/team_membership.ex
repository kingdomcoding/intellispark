defmodule Intellispark.Teams.TeamMembership do
  @moduledoc """
  Joins a Student to a staff User with a team-role (teacher / coach /
  counselor / social_worker / clinician / family / community_partner /
  other). `source: :roster_auto | :manual` distinguishes SIS-synced
  rows (Phase 11) from hand-added ones. `permissions_override` JSONB
  is admin-editable for per-student scope tweaks.
  """

  use Intellispark.Resource, domain: Intellispark.Teams

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :user_id, :role, :source]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["team_memberships:student", :student_id]
    publish_all :update, ["team_memberships:student", :student_id]
    publish_all :destroy, ["team_memberships:student", :student_id]
  end

  postgres do
    table "team_memberships"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      allow_nil? false

      constraints one_of: [
                    :teacher,
                    :coach,
                    :counselor,
                    :social_worker,
                    :clinician,
                    :family,
                    :community_partner,
                    :other
                  ]

      public? true
    end

    attribute :source, :atom do
      allow_nil? false
      default :manual
      constraints one_of: [:roster_auto, :manual]
      public? true
    end

    attribute :added_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true

    attribute :permissions_override, :map, default: %{}, public?: true

    timestamps()
  end

  identities do
    identity :unique_per_student_user_role, [:student_id, :user_id, :role]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :user, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :added_by, Intellispark.Accounts.User, allow_nil?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:student_id, :user_id, :role, :source, :added_at, :permissions_override]
      change Intellispark.Teams.Changes.StampAddedBy
    end

    update :update do
      primary? true
      accept [:role, :permissions_override]
      require_atomic? false
    end

    action :add_members_from_roster, {:array, :struct} do
      constraints items: [instance_of: __MODULE__]

      argument :student_id, :uuid, allow_nil?: false

      argument :staff_user_ids, {:array, :uuid} do
        allow_nil? false
        constraints min_length: 0
      end

      argument :role, :atom do
        allow_nil? false
        default :teacher

        constraints one_of: [
                      :teacher,
                      :coach,
                      :counselor,
                      :social_worker,
                      :clinician,
                      :family,
                      :community_partner,
                      :other
                    ]
      end

      run Intellispark.Teams.Actions.AddMembersFromRoster
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.CounselorOrAdminForStudent
    end

    policy action_type([:update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.CounselorOrAdminForStudent
    end

    policy action(:add_members_from_roster) do
      authorize_if always()
    end
  end
end
