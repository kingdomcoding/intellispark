defmodule Intellispark.Recognition do
  @moduledoc """
  Domain for positive-recognition workflow: reusable
  `HighFiveTemplate`s, sent `HighFive` records with tokenised public
  view links, and an append-only `HighFiveView` audit log. Templates
  and HighFives are tenant-scoped on school_id; HighFiveView inherits
  the tenant via its parent HighFive.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Recognition.HighFiveTemplate do
      define :list_high_five_templates, action: :read
      define :get_high_five_template, action: :read, get_by: [:id]
      define :create_high_five_template, action: :create, args: [:title, :body, :category]
      define :update_high_five_template, action: :update
      define :archive_high_five_template, action: :destroy
    end

    resource Intellispark.Recognition.HighFiveTemplate.Version

    resource Intellispark.Recognition.HighFive do
      define :list_high_fives, action: :read
      define :get_high_five, action: :read, get_by: [:id]

      define :get_high_five_by_token,
        action: :by_token,
        args: [:token],
        get?: true

      define :send_high_five,
        action: :send_to_student,
        args: [:student_id, :title, :body]

      define :bulk_send_high_five,
        action: :bulk_send_to_students,
        args: [:student_ids, :template_id]

      define :record_high_five_view,
        action: :record_view,
        args: [:user_agent, :ip_hash]

      define :resend_high_five, action: :resend

      define :archive_high_five, action: :destroy
    end

    resource Intellispark.Recognition.HighFive.Version

    resource Intellispark.Recognition.HighFiveView do
      define :list_high_five_views, action: :read
    end

    resource Intellispark.Recognition.HighFiveView.Version
  end
end
