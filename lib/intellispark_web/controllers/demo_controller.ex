defmodule IntellisparkWeb.DemoController do
  use IntellisparkWeb, :controller

  require Ash.Query

  alias Intellispark.Accounts.{DemoSession, User}

  @session_ttl_minutes 120
  @xello_embed_token "lMTWIUzOLQJlAZL7P_NgU7W23ubE8ZpSZxKd7FpT2Yw"

  def create_session(conn, %{"persona" => persona})
      when persona in ~w(district_admin counselor xello_embed) do
    persona_atom = String.to_existing_atom(persona)
    do_create(persona_atom, conn)
  end

  def create_session(conn, _), do: send_resp(conn, 404, "Unknown demo persona")

  defp do_create(:district_admin, conn) do
    user = fetch_user!("admin@sandboxhigh.edu")

    conn
    |> store_demo_session(user, :district_admin)
    |> put_user_token(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/students")
  end

  defp do_create(:counselor, conn) do
    user = fetch_user!("counselor@sandboxhigh.edu")

    conn
    |> store_demo_session(user, :counselor)
    |> put_user_token(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/students")
  end

  defp do_create(:xello_embed, conn) do
    token = Application.get_env(:intellispark, :demo_xello_token, @xello_embed_token)
    redirect(conn, to: ~p"/embed/student/#{token}")
  end

  defp put_user_token(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    put_session(conn, "user_token", token)
  end

  defp fetch_user!(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
  end

  defp store_demo_session(conn, user, persona) do
    {:ok, demo} =
      DemoSession
      |> Ash.Changeset.for_create(:create, %{
        persona: persona,
        user_id: user.id,
        ip_hash: ip_hash(conn),
        user_agent_hash: ua_hash(conn),
        expires_at: DateTime.add(DateTime.utc_now(), @session_ttl_minutes * 60, :second)
      })
      |> Ash.create(authorize?: false)

    put_session(conn, :demo_session_id, demo.id)
  end

  defp ip_hash(conn), do: hash(:inet.ntoa(conn.remote_ip) |> to_string())
  defp ua_hash(conn), do: hash(List.first(get_req_header(conn, "user-agent")) || "")
  defp hash(s), do: :crypto.hash(:sha256, s) |> Base.encode16(case: :lower)
end
