defmodule IntellisparkWeb.EmbedLive.StudentTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    world = setup_world()
    student = create_student!(world.school)

    {:ok, embed} =
      Integrations.mint_embed_token(
        %{student_id: student.id, audience: :xello},
        actor: world.admin,
        tenant: world.school.id
      )

    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, %{
      school: world.school,
      admin: world.admin,
      student: student,
      embed: embed
    })
  end

  test "valid token renders SEL grid + flags table", %{conn: conn, embed: embed} do
    {:ok, _lv, html} = live(conn, ~p"/embed/student/#{embed.token}")

    assert html =~ "SEL &amp; Well-Being Indicators"
    assert html =~ "Flags"
    assert html =~ "No flags recorded."
  end

  test "revoked token renders revoked message", %{
    conn: conn,
    embed: embed,
    admin: admin,
    school: school
  } do
    {:ok, _} = Integrations.revoke_embed_token(embed, actor: admin, tenant: school.id)

    {:ok, _lv, html} = live(conn, ~p"/embed/student/#{embed.token}")

    assert html =~ "This embed has been revoked."
  end

  test "unknown token renders not-found", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/embed/student/bogus-token-that-does-not-exist")

    assert html =~ "Embed not found."
  end
end
