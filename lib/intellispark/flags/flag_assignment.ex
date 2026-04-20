defmodule Intellispark.Flags.FlagAssignment do
  @moduledoc """
  Join row — a user currently responsible for a flag. has_many on Flag;
  cleared_at records when the user was removed from the assignment list.
  Paper-trailed so 'who was assigned to this flag last week' is a query.
  """

  use Intellispark.Resource, domain: Intellispark.Flags

  paper_trail do
    attributes_as_attributes [:school_id, :flag_id]
  end

  postgres do
    table "flag_assignments"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :assigned_at, :utc_datetime_usec, allow_nil?: false, default: &DateTime.utc_now/0
    attribute :cleared_at, :utc_datetime_usec
    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :flag, Intellispark.Flags.Flag, allow_nil?: false
    belongs_to :user, Intellispark.Accounts.User, allow_nil?: false
    belongs_to :assigned_by, Intellispark.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_active_assignment, [:flag_id, :user_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:flag_id, :user_id]

      change fn changeset, context ->
        case context.actor do
          %{id: id} -> Ash.Changeset.force_change_attribute(changeset, :assigned_by_id, id)
          _ -> changeset
        end
      end
    end

    update :clear do
      accept []
      change set_attribute(:cleared_at, &DateTime.utc_now/0)
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
