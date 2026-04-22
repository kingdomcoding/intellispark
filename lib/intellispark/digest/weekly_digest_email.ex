defmodule Intellispark.Digest.WeeklyDigestEmail do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Digest.WeeklyDigestComposer.Digest
  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  @spec send(Digest.t()) :: {:ok, term()} | {:error, term()}
  def send(%Digest{user: user} = digest) do
    body_html =
      EmailLayout.wrap(
        heading: "New activity from last week",
        body_html: render_sections(digest.sections),
        cta_url: nil,
        cta_label: nil
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("New activity from last week")
    |> html_body(body_html)
    |> Mailer.deliver()
  end

  defp render_sections(sections) do
    Enum.map_join(sections, "\n", &render_section/1)
  end

  defp render_section({:high_fives, items}) do
    """
    <h2 style="font-size:18px;color:#2b4366;margin-top:24px;border-top:1px solid #eef2f5;padding-top:16px;">
      High-5s 👋
    </h2>
    #{Enum.map_join(items, "", &high_five_row/1)}
    """
  end

  defp render_section({:flags, items}) do
    """
    <h2 style="font-size:18px;color:#2b4366;margin-top:24px;border-top:1px solid #eef2f5;padding-top:16px;">
      Flags ⚠
    </h2>
    #{Enum.map_join(items, "", &flag_row/1)}
    """
  end

  defp render_section({:actions_needed, items}) do
    """
    <h2 style="font-size:18px;color:#2b4366;margin-top:24px;border-top:1px solid #eef2f5;padding-top:16px;">
      Action needed
    </h2>
    #{Enum.map_join(items, "", &action_row/1)}
    """
  end

  defp render_section({:notes, items}) do
    """
    <h2 style="font-size:18px;color:#2b4366;margin-top:24px;border-top:1px solid #eef2f5;padding-top:16px;">
      Notes
    </h2>
    #{Enum.map_join(items, "", &note_row/1)}
    """
  end

  defp high_five_row(hf) do
    """
    <p style="margin:8px 0 4px 0;">
      <a href="#" style="color:#2b4366;text-decoration:underline;">#{display_name(hf.student)}</a>:
      <span style="color:#1f7a3a;font-weight:600;">#{hf.title}</span>
    </p>
    <p style="margin:0 0 12px 0;color:#4b4b4d;">#{hf.body}</p>
    """
  end

  defp flag_row(flag) do
    annotation =
      if Map.get(flag, :assigned_to_recipient?, false),
        do: " <em>(assigned to you)</em>",
        else: ""

    """
    <p style="margin:8px 0;">
      <a href="#" style="color:#2b4366;text-decoration:underline;">#{display_name(flag.student)}</a>: #{flag.flag_type.name}#{annotation}
    </p>
    """
  end

  defp action_row(action) do
    """
    <p style="margin:8px 0;">
      <a href="#" style="color:#2b4366;text-decoration:underline;">#{display_name(action.student)}</a> has been asked to #{action.description}
    </p>
    """
  end

  defp note_row(note) do
    """
    <p style="margin:12px 0 4px 0;">
      <a href="#" style="color:#2b4366;text-decoration:underline;">#{display_name(note.student)}</a>:
    </p>
    <p style="margin:0 0 8px 0;color:#4b4b4d;">#{note.body}</p>
    """
  end

  defp display_name(%{display_name: name}) when is_binary(name), do: name

  defp display_name(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp display_name(_), do: "Student"
end
