defmodule IntellisparkWeb.Plugs.LoadDemoSession do
  import Plug.Conn

  alias Intellispark.Accounts.DemoSession

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :demo_session_id) do
      nil ->
        conn

      id ->
        case Ash.get(DemoSession, id, authorize?: false) do
          {:ok, %DemoSession{expires_at: exp} = demo} ->
            if DateTime.after?(DateTime.utc_now(), exp) do
              delete_session(conn, :demo_session_id)
            else
              assign(conn, :demo_session, demo)
            end

          _ ->
            delete_session(conn, :demo_session_id)
        end
    end
  end
end
