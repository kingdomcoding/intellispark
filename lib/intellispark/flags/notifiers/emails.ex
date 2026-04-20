defmodule Intellispark.Flags.Notifiers.Emails do
  @moduledoc """
  Ash notifier module subscribing to Flag lifecycle events. Dispatches the
  matching Swoosh email without the action definitions needing to know the
  mailer exists. Falls through to :ok for any notification we don't care
  about (so a future action doesn't crash the pipeline).
  """

  use Ash.Notifier

  alias Intellispark.Flags.Emails.{FlagAssigned, FlagAutoClosed}

  @impl true
  def notify(%Ash.Notifier.Notification{
        resource: Intellispark.Flags.Flag,
        action: %{name: name},
        data: flag
      })
      when name in [:open_flag, :assign] do
    with {:ok, flag} <- load_for_email(flag),
         {:ok, opener} <- fetch_opener(flag) do
      for assignment <- active_assignments(flag) do
        FlagAssigned.send(assignment.user, flag, opener)
      end

      :ok
    else
      _ -> :ok
    end
  end

  def notify(%Ash.Notifier.Notification{
        resource: Intellispark.Flags.Flag,
        action: %{name: :auto_close},
        data: flag
      }) do
    with {:ok, flag} <- load_for_email(flag) do
      for assignment <- active_assignments(flag) do
        FlagAutoClosed.send(assignment.user, flag)
      end

      :ok
    else
      _ -> :ok
    end
  end

  def notify(_), do: :ok

  defp load_for_email(flag) do
    case Ash.load(flag, [:student, assignments: [:user]],
           tenant: flag.school_id,
           authorize?: false
         ) do
      {:ok, loaded} -> {:ok, Ash.load!(loaded, [student: [:display_name]], authorize?: false)}
      other -> other
    end
  end

  defp fetch_opener(%{opened_by_id: nil}), do: :error

  defp fetch_opener(%{opened_by_id: id}) do
    case Ash.get(Intellispark.Accounts.User, id, authorize?: false) do
      {:ok, user} -> {:ok, user}
      _ -> :error
    end
  end

  defp active_assignments(%{assignments: %Ash.NotLoaded{}}), do: []

  defp active_assignments(%{assignments: assignments}) do
    Enum.filter(assignments, &is_nil(&1.cleared_at))
  end

  defp active_assignments(_), do: []
end
