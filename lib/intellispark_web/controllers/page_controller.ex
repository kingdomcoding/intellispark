defmodule IntellisparkWeb.PageController do
  use IntellisparkWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
