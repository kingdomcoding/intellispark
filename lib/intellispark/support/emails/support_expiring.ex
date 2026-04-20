defmodule Intellispark.Support.Emails.SupportExpiring do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, supports) when is_list(supports) and supports != [] do
    body_html =
      EmailLayout.wrap(
        heading: "Supports ending this week",
        body_html: """
        <p>You have <strong>#{length(supports)}</strong> support(s) ending within 3 days:</p>
        <ul>
        #{Enum.map_join(supports, "\n", &format_support(&1))}
        </ul>
        """,
        cta_url: "#{host()}/students",
        cta_label: "Open All Students"
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("#{length(supports)} support(s) ending this week")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  def send(_user, _empty), do: :ok

  defp format_support(support) do
    student_name = support.student.display_name |> to_string()
    ends_on = Calendar.strftime(support.ends_at, "%b %-d, %Y")

    """
    <li><a href="#{host()}/students/#{support.student_id}">#{student_name}</a>
    — <strong>#{support.title}</strong> (ends #{ends_on})</li>
    """
  end

  defp host do
    System.get_env("PHX_HOST") || "https://intellispark.josboxoffice.com"
  end
end
