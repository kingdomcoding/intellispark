defmodule Intellispark.Recognition.Changes.MaybeApplyResendEdits do
  @moduledoc """
  Applies optional `:title` / `:body` arguments on the `:resend` action.
  Nil arguments are passthrough — the existing attribute value stays.
  Runs before `SanitizeBody` so edits are sanitized on the same pass.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> maybe_set(:title)
    |> maybe_set(:body)
  end

  defp maybe_set(changeset, field) do
    case Ash.Changeset.get_argument(changeset, field) do
      nil -> changeset
      val -> Ash.Changeset.force_change_attribute(changeset, field, val)
    end
  end
end
