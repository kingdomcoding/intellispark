defmodule Intellispark.Assessments.Emails.SurveyReminder do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(%{student: student, survey_template: template} = assignment)
      when not is_nil(student) do
    to = student.email || raise "SurveyReminder requires student.email"

    url = "#{host()}/surveys/#{assignment.token}"
    first_name = student.first_name

    body_html =
      EmailLayout.wrap(
        heading: "Hi #{first_name} — we'd love to hear from you",
        body_html: """
        <p>We noticed you haven't finished <strong>#{template.name}</strong> yet.</p>
        <p>Your answers really help your teachers understand how you're doing. It only takes a few minutes.</p>
        """,
        cta_url: url,
        cta_label: "Pick up where you left off"
      )

    new()
    |> to(to)
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("Reminder: we'd love your feedback on #{template.name}")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp host,
    do: System.get_env("PHX_HOST_URL") || "https://intellispark.josboxoffice.com"
end
