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

    resource Intellispark.Support.Support do
      define :list_supports, action: :read
      define :get_support, action: :read, get_by: [:id]

      define :create_support,
        action: :create,
        args: [:student_id, :title]

      define :create_support_from_intervention,
        action: :create_from_intervention,
        args: [:student_id, :title]

      define :update_support, action: :update
      define :accept_support, action: :accept
      define :decline_support, action: :decline
      define :complete_support, action: :complete
      define :archive_support, action: :destroy
    end

    resource Intellispark.Support.Support.Version

    resource Intellispark.Support.InterventionLibraryItem do
      define :list_intervention_library_items, action: :read
      define :get_intervention_library_item, action: :read, get_by: [:id]

      define :create_intervention_library_item,
        action: :create,
        args: [:title, :mtss_tier]

      define :update_intervention_library_item, action: :update
      define :archive_intervention_library_item, action: :destroy
    end

    resource Intellispark.Support.InterventionLibraryItem.Version

    resource Intellispark.Support.Note do
      define :list_notes, action: :read
      define :get_note, action: :read, get_by: [:id]

      define :create_note, action: :create, args: [:student_id, :body]
      define :update_note, action: :update
      define :pin_note, action: :pin
      define :unpin_note, action: :unpin
      define :archive_note, action: :destroy
    end

    resource Intellispark.Support.Note.Version
  end
end
