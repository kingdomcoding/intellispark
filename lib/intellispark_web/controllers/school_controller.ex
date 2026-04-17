defmodule IntellisparkWeb.SchoolController do
  use IntellisparkWeb, :controller

  alias Intellispark.Accounts.User

  def set_active(conn, %{"school_id" => school_id}) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "You must sign in first.")
        |> redirect(to: ~p"/sign-in")

      %User{} = user ->
        user = Ash.load!(user, [:school_memberships], authorize?: false)
        belongs? = Enum.any?(user.school_memberships, &(&1.school_id == school_id))

        if belongs? do
          conn
          |> put_session(:current_school_id, school_id)
          |> redirect(to: ~p"/")
        else
          conn
          |> put_flash(:error, "You don't have access to that school.")
          |> redirect(to: ~p"/")
        end
    end
  end
end
