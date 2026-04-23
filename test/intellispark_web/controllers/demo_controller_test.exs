defmodule IntellisparkWeb.DemoControllerTest do
  use IntellisparkWeb.ConnCase, async: false

  import Intellispark.StudentsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)

    %{district: _district, school: school, admin: _admin} = setup_world()

    admin =
      register!("admin@sandboxhigh.edu", "phase1-demo-pass")
      |> attach_district!(school.district_id)
      |> with_membership!(school.id, :admin)

    counselor =
      register!("counselor@sandboxhigh.edu", "phase1-demo-pass")
      |> with_membership!(school.id, :counselor)

    %{school: school, admin: admin, counselor: counselor}
  end

  describe "POST /demo/:persona" do
    test "district_admin stamps a demo session + signs in + redirects", %{conn: conn} do
      conn = post(conn, ~p"/demo/district_admin")

      assert redirected_to(conn) == ~p"/students"
      assert get_session(conn, :demo_session_id)
      assert get_session(conn, "user_token")
    end

    test "counselor stamps a demo session + signs in as counselor", %{conn: conn} do
      conn = post(conn, ~p"/demo/counselor")

      assert redirected_to(conn) == ~p"/students"
      assert get_session(conn, :demo_session_id)
    end

    test "xello_embed redirects directly to /embed/student/...", %{conn: conn} do
      conn = post(conn, ~p"/demo/xello_embed")

      location = redirected_to(conn)
      assert String.starts_with?(location, "/embed/student/")
      refute get_session(conn, :demo_session_id)
    end

    test "unknown persona returns 404", %{conn: conn} do
      conn = post(conn, "/demo/unknown_persona")
      assert conn.status == 404
    end
  end

  describe "sandbox banner" do
    test "renders in the root layout when a demo session is active", %{conn: conn} do
      conn = post(conn, ~p"/demo/district_admin")
      conn = get(conn, ~p"/students")

      assert html_response(conn, 200) =~ "Demo sandbox"
    end

    test "is absent when a non-demo user is signed in", %{conn: conn, admin: admin} do
      conn = conn |> log_in_user(admin) |> get(~p"/students")

      refute html_response(conn, 200) =~ "Demo sandbox"
    end
  end
end
