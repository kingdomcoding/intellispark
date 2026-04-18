defmodule IntellisparkWeb.EmailLayout do
  @moduledoc """
  Shared branded HTML shell for transactional emails. Inline CSS only —
  email clients strip <style> blocks and external stylesheets.
  """

  @doc """
  Wraps `inner` HTML in a branded email layout with heading, CTA button, and
  footer. `cta_url` and `cta_label` render the orange pill button below the body.
  """
  @spec wrap(keyword) :: String.t()
  def wrap(opts) do
    heading = Keyword.fetch!(opts, :heading)
    body_html = Keyword.fetch!(opts, :body_html)
    cta_url = Keyword.fetch!(opts, :cta_url)
    cta_label = Keyword.fetch!(opts, :cta_label)
    footer_html = Keyword.get(opts, :footer_html, default_footer())

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
    </head>
    <body style="margin:0;padding:0;background:#fff6e8;font-family:'Figtree',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#4b4b4d;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fff6e8;padding:32px 16px;">
        <tr><td align="center">
          <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:#ffffff;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:32px 40px 16px 40px;text-align:center;">
                <span style="display:inline-block;font-size:24px;font-weight:700;color:#2b4366;letter-spacing:-0.01em;">Intelli<span style="color:#f26a1b;">spark</span></span>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 40px 0 40px;">
                <h1 style="margin:0 0 16px 0;font-size:24px;font-weight:600;color:#2b4366;line-height:1.3;">#{heading}</h1>
                <div style="font-size:16px;line-height:1.6;color:#4b4b4d;">#{body_html}</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px 40px 32px 40px;">
                <a href="#{cta_url}" style="display:inline-block;background:#f26a1b;color:#ffffff;text-decoration:none;font-weight:600;padding:12px 24px;border-radius:9999px;font-size:16px;">#{cta_label}</a>
              </td>
            </tr>
            <tr>
              <td style="padding:0 40px 32px 40px;border-top:1px solid #eef2f5;">
                <p style="margin:16px 0 0 0;font-size:13px;color:#8a8f96;line-height:1.5;">#{footer_html}</p>
              </td>
            </tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp default_footer do
    "You're receiving this because someone used this address to sign up for Intellispark. " <>
      "If that wasn't you, you can safely ignore this email."
  end
end
