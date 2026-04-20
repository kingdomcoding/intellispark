defmodule Intellispark.Flags.Emails.FlagAssigned do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, flag, opener) do
    student_name = flag.student.display_name |> to_string()
    opener_label = opener.email |> to_string()

    body_html =
      EmailLayout.wrap(
        heading: "A flag needs your attention",
        body_html: """
        <p>#{opener_label} added you as an assignee on a flag for
        <strong>#{student_name}</strong>.</p>
        <p>#{flag.short_description}</p>
        """,
        cta_url: "#{host()}/students/#{flag.student_id}",
        cta_label: "Open Student Hub",
        footer_html:
          "Reply-to-comment support arrives in Phase 13; for now, open the Hub to post a comment."
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("Flag assigned: #{student_name}")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp host do
    System.get_env("PHX_HOST") || "https://intellispark.josboxoffice.com"
  end
end
