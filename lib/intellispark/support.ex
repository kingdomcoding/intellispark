defmodule Intellispark.Support do
  @moduledoc """
  Domain for student-support workflow: follow-up Actions (binary
  completion), Supports (intervention plans with a 4-state lifecycle),
  and Notes (plain-text case notes with pin/unpin + paper-trailed edit
  history). All tenant-scoped on school_id.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Support.Action do
      define :list_actions, action: :read
      define :get_action, action: :read, get_by: [:id]

      define :create_action,
        action: :create,
        args: [:student_id, :assignee_id, :description]

      define :update_action, action: :update
      define :complete_action, action: :complete
      define :cancel_action, action: :cancel
      define :archive_action, action: :destroy
    end

    resource Intellispark.Support.Action.Version
  end
end
