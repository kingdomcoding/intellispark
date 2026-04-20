defmodule Intellispark.Flags do
  @moduledoc """
  Domain for student flag workflow: incident / concern records that carry a
  state machine, per-school flag types, multi-assignee join rows, and a
  future-facing comment thread stub. Every resource here is tenant-scoped
  on school_id.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Flags.FlagType do
      define :list_flag_types, action: :read
      define :get_flag_type, action: :read, get_by: [:id]
      define :create_flag_type, action: :create, args: [:name, :color]
      define :update_flag_type, action: :update
      define :archive_flag_type, action: :destroy
    end

    resource Intellispark.Flags.FlagType.Version
  end
end
