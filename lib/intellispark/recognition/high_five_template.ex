defmodule Intellispark.Recognition.HighFiveTemplate do
  @moduledoc """
  Per-school reusable High-5 message. Title + body + category. Seeded
  with one template per category; schools can add more via AshAdmin.
  """

  use Intellispark.Resource, domain: Intellispark.Recognition

  admin do
    label_field :title
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "high_five_templates"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true

    attribute :category, :atom do
      allow_nil? false
      default :custom

      constraints one_of: [
                    :achievement,
                    :behavior,
                    :attendance,
                    :effort,
                    :kindness,
                    :custom
                  ]

      public? true
    end

    attribute :active?, :boolean, allow_nil?: false, default: true, public?: true

    timestamps()
  end

  identities do
    identity :unique_title_per_school, [:school_id, :title]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    has_many :high_fives, Intellispark.Recognition.HighFive, destination_attribute: :template_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :body, :category, :active?]
    end

    update :update do
      primary? true
      accept [:title, :body, :category, :active?]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type([:update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
