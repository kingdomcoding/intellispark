defmodule Intellispark.Students.CustomList do
  @moduledoc """
  Saved filter + result-on-demand. Owner's private by default; opt-in
  `shared?: true` makes it visible to every staff member in the same
  school.
  """

  use Intellispark.Resource, domain: Intellispark.Students

  admin do
    label_field :name
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "custom_lists"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true

    attribute :filters, Intellispark.Students.FilterSpec,
      allow_nil?: false,
      default: %Intellispark.Students.FilterSpec{},
      public?: true

    attribute :shared?, :boolean, allow_nil?: false, default: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :owner, Intellispark.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :filters, :shared?]
      change relate_actor(:owner)
    end

    update :update do
      primary? true
      accept [:name, :description, :filters, :shared?]
      require_atomic? false
    end

    action :run, {:array, :struct} do
      constraints instance_of: Intellispark.Students.Student
      argument :custom_list_id, :uuid, allow_nil?: false
      run Intellispark.Students.Actions.RunCustomList
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if expr(shared? == true)
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(owner_id == ^actor(:id))
    end

    policy action(:run) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end
  end
end
