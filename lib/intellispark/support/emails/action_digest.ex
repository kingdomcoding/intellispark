defmodule Intellispark.Support.Emails.ActionDigest do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, actions) when is_list(actions) and actions != [] do
    body_html =
      EmailLayout.wrap(
        heading: "Actions due today or overdue",
        body_html: """
        <p>You have <strong>#{length(actions)}</strong> action(s) due today or overdue:</p>
        <ul>
        #{Enum.map_join(actions, "\n", &format_action(&1))}
        </ul>
        """,
        cta_url: "#{host()}/students",
        cta_label: "Open All Students"
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("#{length(actions)} action(s) due today or overdue")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  def send(_user, _empty), do: :ok

  defp format_action(action) do
    student_name = action.student.display_name |> to_string()
    desc = action.description
    due = format_due(action.due_on)

    """
    <li><a href="#{host()}/students/#{action.student_id}">#{student_name}</a>
    — #{desc}#{due}</li>
    """
  end

  defp format_due(nil), do: ""
  defp format_due(date), do: " (due #{Calendar.strftime(date, "%b %-d, %Y")})"

  defp host do
    System.get_env("PHX_HOST") || "https://intellispark.josboxoffice.com"
  end
end
