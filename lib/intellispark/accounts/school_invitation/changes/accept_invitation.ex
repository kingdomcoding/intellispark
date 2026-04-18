defmodule Intellispark.Accounts.SchoolInvitation.Changes.AcceptInvitation do
  @moduledoc """
  Validates a pending invitation, marks it `:accepted`, and creates (or finds)
  the user + their `UserSchoolMembership` inside one transaction.

  The invitation's primary key is the URL token — `data` is the invitation row
  loaded by the controller/LiveView before this update runs. Double-clicks are
  rejected because the `status == :pending` check fails on the second call.
  """

  use Ash.Resource.Change

  alias Intellispark.Accounts.{User, UserSchoolMembership}

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&validate_pending/1)
    |> Ash.Changeset.before_action(&mark_accepted/1)
    |> Ash.Changeset.after_action(&provision_user_and_membership/2)
  end

  defp validate_pending(changeset) do
    invitation = changeset.data

    cond do
      invitation.status != :pending ->
        Ash.Changeset.add_error(changeset, field: :status, message: "invitation is not pending")

      DateTime.compare(invitation.expires_at, DateTime.utc_now()) != :gt ->
        Ash.Changeset.add_error(changeset, field: :expires_at, message: "invitation has expired")

      true ->
        changeset
    end
  end

  defp mark_accepted(changeset) do
    changeset
    |> Ash.Changeset.force_change_attribute(:status, :accepted)
    |> Ash.Changeset.force_change_attribute(:accepted_at, DateTime.utc_now())
  end

  defp provision_user_and_membership(changeset, invitation) do
    email = to_string(invitation.email)

    with {:ok, user} <- find_or_register_user(email, changeset),
         {:ok, _membership} <- ensure_membership(user, invitation) do
      invitation = %{invitation | __metadata__: Map.put(invitation.__metadata__, :user, user)}
      {:ok, invitation}
    end
  end

  defp find_or_register_user(email, changeset) do
    case Ash.read_one(User, filter: [email: email], authorize?: false) do
      {:ok, %User{} = user} ->
        {:ok, user}

      {:ok, nil} ->
        register_new_user(email, changeset)

      other ->
        other
    end
  end

  defp register_new_user(email, changeset) do
    first_name = Ash.Changeset.get_argument(changeset, :first_name)
    last_name = Ash.Changeset.get_argument(changeset, :last_name)

    with {:ok, user} <-
           Ash.create(
             User,
             %{
               email: email,
               password: Ash.Changeset.get_argument(changeset, :password),
               password_confirmation:
                 Ash.Changeset.get_argument(changeset, :password_confirmation)
             },
             action: :register_with_password,
             authorize?: false
           ) do
      if first_name || last_name do
        Ash.update(
          user,
          %{first_name: first_name, last_name: last_name},
          action: :update_profile,
          authorize?: false
        )
      else
        {:ok, user}
      end
    end
  end

  defp ensure_membership(user, invitation) do
    existing =
      Ash.read_one(
        UserSchoolMembership,
        filter: [user_id: user.id, school_id: invitation.school_id],
        authorize?: false
      )

    case existing do
      {:ok, %UserSchoolMembership{} = membership} ->
        {:ok, membership}

      {:ok, nil} ->
        Ash.create(
          UserSchoolMembership,
          %{
            user_id: user.id,
            school_id: invitation.school_id,
            role: invitation.role,
            source: :invitation
          },
          authorize?: false
        )

      other ->
        other
    end
  end
end
