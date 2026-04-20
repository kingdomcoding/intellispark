defmodule Intellispark.Flags.Emails.FollowupDigest do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, flags) when is_list(flags) and flags != [] do
    body_html =
      EmailLayout.wrap(
        heading: "Follow-ups due today",
        body_html: """
        <p>You have <strong>#{length(flags)}</strong> flag(s) awaiting follow-up today:</p>
        <ul>
        #{Enum.map_join(flags, "\n", &format_flag(&1))}
        </ul>
        """,
        cta_url: "#{host()}/students",
        cta_label: "Open All Students"
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("#{length(flags)} flag(s) awaiting your follow-up")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  def send(_user, _empty), do: :ok

  defp format_flag(flag) do
    student_name = flag.student.display_name |> to_string()
    type_name = flag.flag_type.name
    desc = flag.short_description

    """
    <li><a href="#{host()}/students/#{flag.student_id}">#{student_name}</a>
    — <strong>#{type_name}</strong>: #{desc}</li>
    """
  end

  defp host do
    System.get_env("PHX_HOST") || "https://intellispark.josboxoffice.com"
  end
end
