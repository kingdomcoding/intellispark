defmodule Intellispark.Recognition.HighFiveView do
  @moduledoc """
  Append-only audit log of every `/high-fives/:token` click. Indexed by
  `high_five_id` for fast "who viewed this high five" reports.
  """

  use Intellispark.Resource, domain: Intellispark.Recognition

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "high_five_views"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :user_agent, :string, public?: true
    attribute :ip_hash, :string, public?: true
    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :high_five, Intellispark.Recognition.HighFive, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:high_five_id, :user_agent, :ip_hash]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
