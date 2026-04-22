defmodule Intellispark.Recognition.Emails.HighFiveNotification do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(%{recipient_email: to} = high_five) when is_binary(to) do
    student = high_five.student
    sender_name = to_string(high_five.sent_by.email)
    url = "#{host()}/high-fives/#{high_five.token}"

    body_html =
      EmailLayout.wrap(
        hero_icon: "👋",
        heading: high_five.title,
        title_treatment: :pill_green,
        body_html: """
        <p style="font-size:16px;color:#2b4366;font-weight:500;">Hi #{first_name(student)},</p>
        <p>#{sender_name} sent you a High-5 for:</p>
        <div>#{high_five.body}</div>
        """,
        cta_url: url,
        cta_label: "See your High 5",
        footer_html: school_name(student)
      )

    new()
    |> to(to)
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("You got a High 5!")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp first_name(%{preferred_name: name}) when is_binary(name) and name != "", do: name
  defp first_name(%{first_name: name}) when is_binary(name) and name != "", do: name
  defp first_name(_), do: "there"

  defp school_name(%{school: %{name: name}}) when is_binary(name), do: name
  defp school_name(_), do: ""

  defp host do
    System.get_env("PHX_HOST_URL") ||
      "https://intellispark.josboxoffice.com"
  end
end
