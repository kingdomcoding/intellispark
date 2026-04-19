defmodule Intellispark.Accounts.User do
  use Ash.Resource,
    domain: Intellispark.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshPaperTrail.Resource, AshAdmin.Resource]

  admin do
    actor? true
  end

  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at, :hashed_password, :confirmed_at]
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin Intellispark.PaperTrail.VersionPolicies
  end

  postgres do
    table "users"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :first_name, :string, public?: true
    attribute :last_name, :string, public?: true

    attribute :confirmed_at, :utc_datetime_usec

    timestamps()
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    belongs_to :district, Intellispark.Accounts.District
    has_many :school_memberships, Intellispark.Accounts.UserSchoolMembership
  end

  authentication do
    tokens do
      enabled? true
      token_resource Intellispark.Accounts.Token
      signing_secret Intellispark.Accounts.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? true
        sign_in_tokens_enabled? true

        resettable do
          sender Intellispark.Accounts.User.Senders.SendPasswordResetEmail
        end
      end
    end

    add_ons do
      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        sender Intellispark.Accounts.User.Senders.SendConfirmationEmail
      end
    end
  end

  actions do
    defaults [:read]

    update :update_profile do
      accept [:first_name, :last_name]
      require_atomic? false
    end

    update :set_district do
      accept [:district_id]
      require_atomic? false
    end

    destroy :destroy do
      primary? true
      require_atomic? false
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfUser
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfUser
    end

    policy action(:set_district) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfUser
    end

    policy action(:destroy) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfUser
    end
  end
end
