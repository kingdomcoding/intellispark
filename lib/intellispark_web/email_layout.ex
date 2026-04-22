defmodule IntellisparkWeb.EmailLayout do
  @moduledoc """
  Shared branded HTML shell for transactional emails. Inline CSS only —
  email clients strip <style> blocks and external stylesheets.
  """

  @logo_url "https://intellispark.example.com/images/logo-150.png"
  @footer_company """
  1390 Chain Bridge Road · Suite 10071 · McLean, VA 22101 USA<br>
  +1 703-397-8700 · <a href="https://intellispark.example.com" style="color:#ffffff;text-decoration:underline;">intellispark.com</a>
  """

  @spec wrap(keyword) :: String.t()
  def wrap(opts) do
    heading = Keyword.fetch!(opts, :heading)
    body_html = Keyword.fetch!(opts, :body_html)
    cta_url = Keyword.get(opts, :cta_url)
    cta_label = Keyword.get(opts, :cta_label)
    title_treatment = Keyword.get(opts, :title_treatment, :default)
    hero_icon = Keyword.get(opts, :hero_icon)
    footer_html = Keyword.get(opts, :footer_html, default_footer())

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
    </head>
    <body style="margin:0;padding:0;background:linear-gradient(135deg,#e85d3a 0%,#f29554 100%);font-family:'Figtree',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#4b4b4d;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:linear-gradient(135deg,#e85d3a 0%,#f29554 100%);padding:32px 16px;">
        <tr><td align="center">
          <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">
            <tr><td align="center" style="padding:0 0 24px 0;">
              <img src="#{@logo_url}" alt="Intellispark" width="180" style="display:block;border:0;outline:none;text-decoration:none;" />
            </td></tr>
          </table>

          #{hero_block(hero_icon)}

          <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:#ffffff;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:32px 40px 16px 40px;">
                #{heading_block(heading, title_treatment)}
                <div style="font-size:16px;line-height:1.6;color:#4b4b4d;">#{body_html}</div>
              </td>
            </tr>
            #{cta_block(cta_url, cta_label)}
          </table>

          <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">
            <tr><td align="center" style="padding:24px 0 0 0;color:#ffffff;font-size:13px;line-height:1.6;text-align:center;">
              #{footer_html}
              <div style="margin-top:16px;">#{@footer_company}</div>
              <div style="margin-top:12px;">
                <a href="https://facebook.com/intellispark" style="color:#ffffff;margin:0 8px;text-decoration:none;">f</a>
                <a href="https://twitter.com/intellispark" style="color:#ffffff;margin:0 8px;text-decoration:none;">t</a>
                <a href="https://linkedin.com/company/intellispark" style="color:#ffffff;margin:0 8px;text-decoration:none;">in</a>
              </div>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp heading_block(text, :pill_green) do
    """
    <p style="margin:0 0 16px 0;">
      <span style="display:inline-block;padding:8px 16px;background:#dff5e0;color:#1f7a3a;border-radius:8px;font-size:18px;font-weight:600;">
        #{text}
      </span>
    </p>
    """
  end

  defp heading_block(text, _) do
    "<h1 style=\"margin:0 0 16px 0;font-size:24px;font-weight:600;color:#2b4366;line-height:1.3;\">#{text}</h1>"
  end

  defp cta_block(nil, _), do: ""
  defp cta_block(_, nil), do: ""

  defp cta_block(url, label) do
    """
    <tr>
      <td style="padding:16px 40px 32px 40px;">
        <a href="#{url}" style="display:inline-block;background:#f26a1b;color:#ffffff;text-decoration:none;font-weight:600;padding:12px 24px;border-radius:9999px;font-size:16px;">#{label}</a>
      </td>
    </tr>
    """
  end

  defp hero_block(nil), do: ""

  defp hero_block(emoji) when is_binary(emoji) do
    """
    <div style="text-align:center;padding-bottom:8px;">
      <span style="font-size:48px;color:#ffffff;">#{emoji}</span>
    </div>
    """
  end

  defp default_footer do
    "You're receiving this because you have an Intellispark account."
  end
end
