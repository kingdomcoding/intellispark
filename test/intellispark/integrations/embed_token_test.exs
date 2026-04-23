defmodule Intellispark.Integrations.EmbedTokenTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations

  setup do
    world = setup_world()
    student = create_student!(world.school)
    {:ok, Map.put(world, :student, student)}
  end

  test "mint generates a token + expires_at ~1 year out",
       %{school: school, student: student, admin: admin} do
    {:ok, token} =
      Integrations.mint_embed_token(%{student_id: student.id, audience: :xello},
        actor: admin,
        tenant: school.id
      )

    assert byte_size(token.token) == 43
    assert token.audience == :xello
    assert token.revoked_at == nil

    days_to_expire = DateTime.diff(token.expires_at, DateTime.utc_now(), :day)
    assert days_to_expire >= 364 and days_to_expire <= 366
  end

  test "revoke sets revoked_at", %{school: school, student: student, admin: admin} do
    {:ok, token} =
      Integrations.mint_embed_token(%{student_id: student.id, audience: :xello},
        actor: admin,
        tenant: school.id
      )

    {:ok, revoked} =
      Integrations.revoke_embed_token(token, actor: admin, tenant: school.id)

    assert revoked.revoked_at != nil
  end

  test "regenerate replaces token + clears revoked_at",
       %{school: school, student: student, admin: admin} do
    {:ok, token} =
      Integrations.mint_embed_token(%{student_id: student.id, audience: :xello},
        actor: admin,
        tenant: school.id
      )

    {:ok, revoked} =
      Integrations.revoke_embed_token(token, actor: admin, tenant: school.id)

    {:ok, regenerated} =
      Integrations.regenerate_embed_token(revoked, actor: admin, tenant: school.id)

    assert regenerated.token != token.token
    assert regenerated.revoked_at == nil
  end
end
