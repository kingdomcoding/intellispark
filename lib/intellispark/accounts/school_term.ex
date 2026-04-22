defmodule Intellispark.Accounts.SchoolTerm do
  use Intellispark.Resource, domain: Intellispark.Accounts

  require Ash.Query

  postgres do
    table "school_terms"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :starts_on, :date, allow_nil?: false, public?: true
    attribute :ends_on, :date, allow_nil?: false, public?: true
    attribute :is_current?, :boolean, default: false, allow_nil?: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :starts_on, :ends_on, :is_current?, :school_id]
    end

    update :update do
      accept [:name, :starts_on, :ends_on, :is_current?]
      primary? true
      require_atomic? false
    end

    update :mark_current do
      accept []
      require_atomic? false
      change set_attribute(:is_current?, true)

      change after_action(fn _changeset, term, _context ->
               Intellispark.Accounts.SchoolTerm
               |> Ash.Query.filter(school_id == ^term.school_id and id != ^term.id)
               |> Ash.bulk_update!(:update, %{is_current?: false}, authorize?: false)

               {:ok, term}
             end)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:school, :memberships, :user])
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchoolTerm
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminForSchoolScopedCreate
    end

    policy action_type([:update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchoolTerm
    end
  end
end
