defmodule Intellispark.Flags.FlagComment do
  @moduledoc """
  Threaded discussion on a Flag. Phase 4 ships the schema so Phase 13
  doesn't need a migration; UI for adding / reading comments arrives
  with Real-Time Collaboration.
  """

  use Intellispark.Resource, domain: Intellispark.Flags

  paper_trail do
    attributes_as_attributes [:school_id, :flag_id]
  end

  postgres do
    table "flag_comments"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :body, :string, allow_nil?: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :flag, Intellispark.Flags.Flag, allow_nil?: false
    belongs_to :author, Intellispark.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:flag_id, :body]

      change fn changeset, context ->
        case context.actor do
          %{id: id} -> Ash.Changeset.force_change_attribute(changeset, :author_id, id)
          _ -> changeset
        end
      end
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
