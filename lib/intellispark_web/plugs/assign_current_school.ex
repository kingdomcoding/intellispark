defmodule IntellisparkWeb.Plugs.AssignCurrentSchool do
  @moduledoc """
  Resolves the authenticated user's active school from the session (or falls back
  to their first school membership) and assigns it to `conn.assigns[:current_school]`.

  Runs in the :browser pipeline after AshAuthentication's `:load_from_session` so
  `conn.assigns[:current_user]` is already populated. Works for both controller
  actions and LiveView mounts — LiveViews also re-derive this via the
  `IntellisparkWeb.LiveUserAuth.:assign_current_school` on_mount hook.
  """

  import Plug.Conn

  alias Intellispark.Accounts
  alias Intellispark.Accounts.{School, UserSchoolMembership}

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    cond do
      current_user == nil ->
        assign(conn, :current_school, nil)

      true ->
        user =
          current_user
          |> Ash.load!([:school_memberships], authorize?: false)

        school_id = get_session(conn, :current_school_id)

        school =
          resolve_school(user, school_id) ||
            resolve_default_school(user)

        conn
        |> assign(:current_user, user)
        |> assign(:current_school, school)
    end
  end

  defp resolve_school(_user, nil), do: nil

  defp resolve_school(user, school_id) do
    if Enum.any?(user.school_memberships, &(&1.school_id == school_id)) do
      case Ash.get(School, school_id, authorize?: false) do
        {:ok, school} -> school
        _ -> nil
      end
    end
  end

  defp resolve_default_school(%{school_memberships: [%UserSchoolMembership{school_id: id} | _]}) do
    case Ash.get(School, id, authorize?: false) do
      {:ok, school} -> school
      _ -> nil
    end
  end

  defp resolve_default_school(_), do: nil

  # Silence "unused alias" if Accounts becomes unused later.
  _ = Accounts
end
