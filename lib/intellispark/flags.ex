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

    resource Intellispark.Flags.Flag do
      define :list_flags, action: :read
      define :get_flag, action: :read, get_by: [:id]

      define :create_flag,
        action: :create,
        args: [:student_id, :flag_type_id, :description]

      define :archive_flag, action: :destroy

      define :open_flag, action: :open_flag, args: [:assignee_ids]
      define :assign_flag, action: :assign, args: [:assignee_ids]
      define :move_flag_to_review, action: :move_to_review
      define :set_flag_followup, action: :set_followup, args: [:followup_at]
      define :close_flag, action: :close_with_resolution, args: [:resolution_note]
      define :auto_close_flag, action: :auto_close
      define :reopen_flag, action: :reopen
    end

    resource Intellispark.Flags.FlagAssignment do
      define :list_flag_assignments, action: :read
      define :clear_flag_assignment, action: :clear
    end

    resource Intellispark.Flags.FlagComment do
      define :list_flag_comments, action: :read
      define :add_flag_comment, action: :create, args: [:flag_id, :body]
    end

    resource Intellispark.Flags.FlagType.Version
    resource Intellispark.Flags.Flag.Version
    resource Intellispark.Flags.FlagAssignment.Version
    resource Intellispark.Flags.FlagComment.Version
  end
end
