defmodule Intellispark.Assessments.Emails.SurveyInvitation do
  @moduledoc false

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(%{student: student, survey_template: template} = assignment)
      when not is_nil(student) do
    to = student.email || raise "SurveyInvitation requires student.email"

    duration = template.duration_minutes || 5
    url = "#{host()}/surveys/#{assignment.token}"
    first_name = student.first_name

    body_html =
      EmailLayout.wrap(
        heading: "Hi #{first_name} — a quick check-in from school",
        body_html: """
        <p>Your school would love your feedback on <strong>#{template.name}</strong>.</p>
        <p>It takes about <strong>#{duration} minutes</strong>. Your answers help us understand how you're doing.</p>
        """,
        cta_url: url,
        cta_label: "Start the survey"
      )

    new()
    |> to(to)
    |> from({"Intellispark", "no-reply@intellispark.example.com"})
    |> subject("A quick check-in: #{template.name}")
    |> html_body(body_html)
    |> Mailer.deliver!()
  end

  defp host,
    do: System.get_env("PHX_HOST_URL") || "https://intellispark.josboxoffice.com"
end
