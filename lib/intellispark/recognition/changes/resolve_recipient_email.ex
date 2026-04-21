defmodule Intellispark.Recognition.Changes.ResolveRecipientEmail do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :recipient_email) do
      email when is_binary(email) and email != "" ->
        changeset

      _ ->
        student_id = Ash.Changeset.get_attribute(changeset, :student_id)

        case Ash.get(Intellispark.Students.Student, student_id,
               tenant: changeset.tenant,
               authorize?: false
             ) do
          {:ok, %{email: email}} when is_binary(email) and email != "" ->
            Ash.Changeset.force_change_attribute(changeset, :recipient_email, email)

          _ ->
            Ash.Changeset.add_error(
              changeset,
              field: :recipient_email,
              message: "no email on record for this student — pick an override"
            )
        end
    end
  end
end
