defmodule Intellispark.Flags.Emails.FlagAutoClosed do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, flag) do
    student_name = flag.student.display_name |> to_string()

    body_html =
      EmailLayout.wrap(
        heading: "Hi #{first_name(user)},",
        body_html: """
        <p>A flag on <strong>#{student_name}</strong> was automatically closed after
        30 days without activity.</p>
        <p>#{flag.short_description}</p>
        <p>If this flag needs more follow-up, reopen it from the Student Hub.</p>
        """,
        cta_url: "#{host()}/students/#{flag.student_id}",
        cta_label: "Open Student Hub"
      )

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("Flag auto-closed: #{student_name}")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp host do
    System.get_env("PHX_HOST") || "https://intellispark.josboxoffice.com"
  end

  defp first_name(%{first_name: name}) when is_binary(name) and name != "", do: name

  defp first_name(%{email: email}) when is_binary(email) do
    email |> String.split("@") |> List.first()
  end

  defp first_name(_), do: "there"
end
