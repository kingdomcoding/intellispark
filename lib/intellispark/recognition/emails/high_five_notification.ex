defmodule Intellispark.Recognition.Emails.HighFiveNotification do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(%{recipient_email: to} = high_five) when is_binary(to) do
    student_name = to_string(high_five.student.display_name)
    sender_name = to_string(high_five.sent_by.email)
    url = "#{host()}/high-fives/#{high_five.token}"

    body_html =
      EmailLayout.wrap(
        heading: "#{student_name} — you got a High 5!",
        body_html: """
        <p><strong>#{sender_name}</strong> just sent you a High 5:</p>
        <blockquote style="border-left:4px solid #f26a1b;padding:8px 16px;margin:16px 0;background:#fff6e8;">
          <p style="font-weight:600;margin:0 0 8px 0;">#{high_five.title}</p>
          <p style="white-space:pre-line;margin:0;">#{high_five.body}</p>
        </blockquote>
        <p>Click the button below to see the full message.</p>
        """,
        cta_url: url,
        cta_label: "See your High 5"
      )

    new()
    |> to(to)
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("You got a High 5!")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp host do
    System.get_env("PHX_HOST_URL") ||
      "https://intellispark.josboxoffice.com"
  end
end
