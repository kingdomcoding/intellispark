defmodule Intellispark.Accounts.District do
  use Intellispark.Resource, domain: Intellispark.Accounts

  postgres do
    table "districts"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    timestamps()
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    has_many :schools, Intellispark.Accounts.School
    has_many :users, Intellispark.Accounts.User
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug]
    end

    update :update do
      accept [:name, :slug]
      primary? true
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:users)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if never()
    end
  end
end
