defmodule Intellispark.Flags.Emails.FlagAssigned do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, flag, opener) do
    student_name = flag.student.display_name |> to_string()
    opener_name = opener.email |> to_string()
    url = "#{host()}/students/#{flag.student_id}?tab=flag:#{flag.id}"

    body_html =
      EmailLayout.wrap(
        heading: "Hi #{first_name(user)},",
        body_html: """
        <p>#{opener_name} opened this flag in reference to <strong>#{student_name}</strong>
        and it has been assigned to you.</p>
        <p style="margin-top:16px;font-weight:600;">Flag: #{flag.flag_type.name}</p>
        <p style="white-space:pre-line;">#{flag.short_description}</p>
        <p>Click <a href="#{url}" style="color:#f26a1b;font-weight:600;">here</a> to view details.</p>
        """,
        cta_url: nil,
        cta_label: nil
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("#{student_name} - New flag assigned to you")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp first_name(%{first_name: name}) when is_binary(name) and name != "", do: name

  defp first_name(%{email: email}) when is_binary(email) do
    email |> String.split("@") |> List.first()
  end

  defp first_name(_), do: "there"

  defp host do
    System.get_env("PHX_HOST") || "https://intellispark.josboxoffice.com"
  end
end
