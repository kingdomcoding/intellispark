defmodule IntellisparkWeb.AuthController do
  use IntellisparkWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, {:password, _}, _reason) do
    conn
    |> put_flash(:error, "Invalid email or password.")
    |> redirect(to: ~p"/sign-in")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Authentication failed.")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    demo_id = get_session(conn, :demo_session_id)

    if demo_id do
      case Ash.get(Intellispark.Accounts.DemoSession, demo_id, authorize?: false) do
        {:ok, demo} -> Ash.destroy!(demo, authorize?: false)
        _ -> :ok
      end
    end

    conn
    |> clear_session(:intellispark)
    |> delete_session(:demo_session_id)
    |> redirect(to: ~p"/")
  end
end
