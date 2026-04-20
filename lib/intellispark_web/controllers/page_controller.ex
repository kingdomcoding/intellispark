defmodule IntellisparkWeb.PageController do
  use IntellisparkWeb, :controller

  def home(conn, _params) do
    case conn.assigns[:current_user] do
      nil -> render(conn, :home)
      _user -> redirect(conn, to: ~p"/students")
    end
  end
end
