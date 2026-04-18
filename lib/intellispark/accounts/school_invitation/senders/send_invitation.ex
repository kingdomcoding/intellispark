defmodule Intellispark.Accounts.SchoolInvitation.Senders.SendInvitation do
  @moduledoc """
  Delivers a branded invitation email pointing at `/invitations/:id`. Uses
  `EmailLayout.wrap/1` for consistency with confirm + reset emails.
  """

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout
  alias IntellisparkWeb.Endpoint

  def send(invitation) do
    school = invitation.school.name
    inviter = display_name(invitation.inviter)
    role_label = role_label(invitation.role)
    accept_url = Endpoint.url() <> "/invitations/#{invitation.id}"

    new()
    |> to(to_string(invitation.email))
    |> from({"Intellispark", "no-reply@intellispark.local"})
    |> subject("#{inviter} invited you to #{school}")
    |> html_body(html(school, inviter, role_label, accept_url))
    |> text_body(text(school, inviter, role_label, accept_url))
    |> Mailer.deliver!()
  end

  defp html(school, inviter, role, url) do
    EmailLayout.wrap(
      heading: "You're invited to #{school}",
      body_html: """
      <p style="margin:0 0 12px 0;">
        <strong>#{inviter}</strong> invited you to join <strong>#{school}</strong>
        as a <strong>#{role}</strong>.
      </p>
      <p style="margin:0;">
        Click the button below to set your password and finish creating your account.
        This invitation expires in 7 days.
      </p>
      """,
      cta_url: url,
      cta_label: "Accept invitation",
      footer_html:
        "Didn't expect this? You can safely ignore this email — nothing changes until you click the link."
    )
  end

  defp text(school, inviter, role, url) do
    """
    #{inviter} invited you to join #{school} as a #{role}.

    Accept the invitation:
    #{url}

    This link expires in 7 days.
    """
  end

  defp display_name(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp display_name(%{first_name: f}) when is_binary(f), do: f
  defp display_name(%{last_name: l}) when is_binary(l), do: l
  defp display_name(%{email: email}), do: to_string(email)

  defp role_label(:admin), do: "school admin"
  defp role_label(:counselor), do: "counselor"
  defp role_label(:teacher), do: "teacher"
  defp role_label(:social_worker), do: "social worker"
  defp role_label(:clinician), do: "clinician"
  defp role_label(:support_staff), do: "support staff"
end
