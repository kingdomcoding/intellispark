defmodule IntellisparkWeb.DemoController do
  use IntellisparkWeb, :controller

  def create_session(conn, _params) do
    send_resp(conn, 501, "Demo auth implemented in LP-2")
  end
end
