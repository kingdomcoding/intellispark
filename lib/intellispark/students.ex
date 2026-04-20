defmodule Intellispark.Students do
  @moduledoc """
  Domain for student records, per-school tagging + status, and saved
  CustomList filters. Every resource here is tenant-scoped by school_id.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
  end
end
