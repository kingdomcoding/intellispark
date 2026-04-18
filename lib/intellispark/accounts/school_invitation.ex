defmodule Intellispark.Accounts.SchoolInvitation do
  use Intellispark.Resource, domain: Intellispark.Accounts

  postgres do
    table "school_invitations"
    repo Intellispark.Repo

    identity_wheres_to_sql one_pending_per_email_school: "status = 'pending'"
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :admin,
                    :counselor,
                    :teacher,
                    :social_worker,
                    :clinician,
                    :support_staff
                  ]
    end

    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :accepted, :revoked]
    end

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false
    attribute :accepted_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :inviter, Intellispark.Accounts.User, allow_nil?: false
  end

  identities do
    identity :one_pending_per_email_school, [:email, :school_id],
      where: expr(status == :pending)
  end

  actions do
    defaults [:read]

    create :invite do
      accept [:email, :school_id, :role]

      change Intellispark.Accounts.SchoolInvitation.Changes.PrepareInvite
      change Intellispark.Accounts.SchoolInvitation.Changes.SendInvitationEmail
    end

    update :accept_by_token do
      argument :password, :string, sensitive?: true, allow_nil?: false
      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false
      argument :first_name, :string
      argument :last_name, :string

      require_atomic? false

      change Intellispark.Accounts.SchoolInvitation.Changes.AcceptInvitation
    end

    update :revoke do
      change set_attribute(:status, :revoked)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action(:invite) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchoolInvitation
    end

    policy action(:revoke) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchoolInvitation
    end

    policy action(:accept_by_token) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchoolInvitation
    end
  end
end
