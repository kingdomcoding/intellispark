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
  end
end
