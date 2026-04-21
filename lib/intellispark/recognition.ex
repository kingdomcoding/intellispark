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
  end
end
