defmodule IntellisparkWeb.XelloWebhookControllerTest do
  use IntellisparkWeb.ConnCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    world = setup_world()
    set_school_tier!(world.school, :pro)

    student = create_student!(world.school, %{external_id: "SIS-001"})

    admin_with_school =
      world.admin
      |> Map.put(:current_school, Ash.load!(world.school, [:subscription], authorize?: false))

    {:ok, provider} =
      Integrations.create_provider(
        %{
          provider_type: :xello,
          name: "Xello sandbox",
          credentials: %{"webhook_secret" => "shhh-secret"}
        },
        actor: admin_with_school,
        tenant: world.school.id
      )

    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, %{
      school: world.school,
      student: student,
      provider: provider
    })
  end

  defp sign(body, secret, ts) do
    :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{body}") |> Base.encode16(case: :lower)
  end

  defp timestamp, do: DateTime.utc_now() |> DateTime.to_unix()

  test "valid signature + known student → 204 + profile upserted",
       %{conn: conn, school: school, provider: provider, student: student} do
    body =
      Jason.encode!(%{
        "student_external_id" => "SIS-001",
        "personality_style" => %{"builder_realistic" => "strong"},
        "skills" => ["Problem solving"]
      })

    ts = timestamp()
    sig = "t=#{ts},v1=#{sign(body, "shhh-secret", ts)}"

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-xello-signature", sig)
      |> put_req_header("x-xello-provider-id", provider.id)
      |> post(~p"/api/xello/webhook", body)

    assert conn.status == 204

    profile =
      Integrations.get_profile_by_student!(student.id, tenant: school.id, authorize?: false)

    assert profile.personality_style == %{"builder_realistic" => "strong"}
    assert profile.skills == ["Problem solving"]
  end

  test "bad signature → 400", %{conn: conn, provider: provider} do
    body = Jason.encode!(%{"student_external_id" => "SIS-001"})
    ts = timestamp()
    sig = "t=#{ts},v1=#{sign(body, "wrong-secret", ts)}"

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-xello-signature", sig)
      |> put_req_header("x-xello-provider-id", provider.id)
      |> post(~p"/api/xello/webhook", body)

    assert conn.status == 400
  end

  test "replay window exceeded → 400", %{conn: conn, provider: provider} do
    body = Jason.encode!(%{"student_external_id" => "SIS-001"})
    # 10 minutes ago
    ts = DateTime.utc_now() |> DateTime.add(-600, :second) |> DateTime.to_unix()
    sig = "t=#{ts},v1=#{sign(body, "shhh-secret", ts)}"

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-xello-signature", sig)
      |> put_req_header("x-xello-provider-id", provider.id)
      |> post(~p"/api/xello/webhook", body)

    assert conn.status == 400
  end

  test "unknown provider id → 401", %{conn: conn} do
    body = Jason.encode!(%{"student_external_id" => "SIS-001"})
    ts = timestamp()
    sig = "t=#{ts},v1=#{sign(body, "shhh-secret", ts)}"

    bogus_id = "00000000-0000-0000-0000-000000000000"

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-xello-signature", sig)
      |> put_req_header("x-xello-provider-id", bogus_id)
      |> post(~p"/api/xello/webhook", body)

    assert conn.status == 401
  end
end
