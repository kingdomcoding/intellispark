defmodule IntellisparkWeb.XelloWebhookController do
  @moduledoc """
  Receives Xello profile-updated webhooks. Verifies HMAC-SHA256
  signature + replay window, then upserts the corresponding
  `XelloProfile`. Response codes: 204 on success; 400 on bad
  signature / stale timestamp / malformed payload; 401 on unknown
  provider; 404 if the referenced student doesn't exist in the
  provider's school.
  """

  use IntellisparkWeb, :controller

  require Ash.Query

  alias Intellispark.Integrations
  alias Intellispark.Students.Student

  @max_replay_age_seconds 300

  def receive(conn, _params) do
    body = raw_body(conn)
    signature = get_req_header(conn, "x-xello-signature") |> List.first()
    provider = conn.assigns[:xello_provider]

    with {:ok, ts, hmac_hex} <- parse_signature(signature),
         :ok <- check_replay(ts),
         :ok <- verify_hmac(body, ts, hmac_hex, provider),
         {:ok, payload} <- Jason.decode(body),
         {:ok, _profile} <- upsert_profile(payload, provider) do
      send_resp(conn, 204, "")
    else
      {:error, :invalid_signature} -> send_resp(conn, 400, "invalid signature")
      {:error, :replay_window} -> send_resp(conn, 400, "replay window exceeded")
      {:error, :student_not_found} -> send_resp(conn, 404, "student not found")
      _ -> send_resp(conn, 400, "bad request")
    end
  end

  defp raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil -> ""
      chunks -> chunks |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end

  defp parse_signature(nil), do: {:error, :invalid_signature}

  defp parse_signature(header) when is_binary(header) do
    with [t_part, v_part] <- String.split(header, ","),
         "t=" <> ts <- t_part,
         "v1=" <> hmac_hex <- v_part,
         {ts_int, ""} <- Integer.parse(ts) do
      {:ok, ts_int, hmac_hex}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp check_replay(ts) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    if abs(now - ts) <= @max_replay_age_seconds, do: :ok, else: {:error, :replay_window}
  end

  defp verify_hmac(body, ts, hmac_hex, %{credentials: %{"webhook_secret" => secret}})
       when is_binary(secret) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{body}")
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, hmac_hex),
      do: :ok,
      else: {:error, :invalid_signature}
  end

  defp verify_hmac(_body, _ts, _hmac, _provider), do: {:error, :invalid_signature}

  defp upsert_profile(%{"student_external_id" => sis_id} = payload, provider) do
    case find_student(sis_id, provider.school_id) do
      nil ->
        {:error, :student_not_found}

      student ->
        Integrations.upsert_xello_profile(
          %{
            student_id: student.id,
            personality_style: payload["personality_style"] || %{},
            learning_style: payload["learning_style"] || %{},
            education_goals: payload["education_goals"],
            favorite_career_clusters: payload["favorite_career_clusters"] || [],
            skills: payload["skills"] || [],
            interests: payload["interests"] || [],
            birthplace: payload["birthplace"],
            live_in: payload["live_in"],
            family_roots: payload["family_roots"],
            suggested_clusters: payload["suggested_clusters"] || []
          },
          tenant: provider.school_id,
          authorize?: false
        )
    end
  end

  defp upsert_profile(_payload, _provider), do: {:error, :bad_request}

  defp find_student(sis_id, school_id) do
    Student
    |> Ash.Query.filter(external_id == ^sis_id)
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, student} -> student
      _ -> nil
    end
  end
end
