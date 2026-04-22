defmodule IntellisparkWeb.LiveUserAuth do
  @moduledoc """
  on_mount hooks that load `current_user` and resolve `current_school` for
  every authenticated LiveView. Wired via `ash_authentication_live_session`
  in the router.
  """

  use IntellisparkWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]

  alias Intellispark.Accounts
  alias Intellispark.Accounts.{School, UserSchoolMembership}

  def on_mount(:live_user_required, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns[:current_user] do
      {:cont, assign_current_school(socket, session)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = assign_current_user(socket, session)
    {:cont, assign_current_school(socket, session)}
  end

  def on_mount(:live_no_user, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:require_district_admin, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if district_admin?(user) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Admin access required.")
       |> Phoenix.LiveView.redirect(to: ~p"/")}
    end
  end

  defp district_admin?(nil), do: false

  defp district_admin?(user) do
    user.district_id != nil and
      Enum.any?(user.school_memberships || [], &(&1.role == :admin))
  end

  defp assign_current_user(socket, session) do
    case session_user(session) do
      {:ok, user} ->
        user = Ash.load!(user, [school_memberships: [:school]], authorize?: false)
        assign(socket, :current_user, user)

      :error ->
        assign(socket, :current_user, nil)
    end
  end

  defp session_user(session) do
    token =
      session["user_token"] ||
        Map.get(session, :user_token) ||
        get_in(session, ["user", "user_token"])

    with token when is_binary(token) <- token,
         {:ok, %{"sub" => subject}, _resource} <-
           AshAuthentication.Jwt.verify(token, :intellispark),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, Accounts.User) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp assign_current_school(socket, session) do
    user = socket.assigns[:current_user]

    cond do
      user == nil ->
        assign(socket, :current_school, nil)

      school_id = session["current_school_id"] ->
        case load_school_for_user(user, school_id) do
          {:ok, school} -> assign_school(socket, school)
          :error -> assign_default_school(socket, user)
        end

      true ->
        assign_default_school(socket, user)
    end
  end

  defp assign_school(socket, school) do
    user = socket.assigns[:current_user]
    user_with_school = Map.put(user, :current_school, school)

    socket
    |> assign(:current_school, school)
    |> assign(:current_user, user_with_school)
  end

  defp load_school_for_user(user, school_id) do
    if Enum.any?(user.school_memberships || [], &(&1.school_id == school_id)) do
      case Ash.get(School, school_id, load: [:subscription, :onboarding_state], authorize?: false) do
        {:ok, school} -> {:ok, school}
        _ -> :error
      end
    else
      :error
    end
  end

  defp assign_default_school(socket, user) do
    case user.school_memberships do
      [%UserSchoolMembership{school_id: id} | _] ->
        case Ash.get(School, id, load: [:subscription, :onboarding_state], authorize?: false) do
          {:ok, school} -> assign_school(socket, school)
          _ -> assign(socket, :current_school, nil)
        end

      _ ->
        assign(socket, :current_school, nil)
    end
  end
end
