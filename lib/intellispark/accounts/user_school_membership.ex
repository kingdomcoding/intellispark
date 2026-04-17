defmodule Intellispark.Accounts.UserSchoolMembership do
  use Intellispark.Resource, domain: Intellispark.Accounts

  postgres do
    table "user_school_memberships"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      allow_nil? false

      constraints one_of: [
                    :admin,
                    :counselor,
                    :teacher,
                    :social_worker,
                    :clinician,
                    :support_staff
                  ]

      public? true
    end

    attribute :source, :atom do
      allow_nil? false
      default :manual
      constraints one_of: [:manual, :roster_auto]
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_user_school, [:user_id, :school_id]
  end

  relationships do
    belongs_to :user, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :school_id, :role, :source]
    end

    update :update_role do
      accept [:role]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfMembership
    end

    policy action_type([:create, :destroy]) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfMembership
    end

    policy action(:update_role) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfMembership
    end
  end
end
