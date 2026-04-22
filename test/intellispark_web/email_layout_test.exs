defmodule IntellisparkWeb.EmailLayoutTest do
  use ExUnit.Case, async: true

  alias IntellisparkWeb.EmailLayout

  test "wraps body with logo + heading + footer" do
    html =
      EmailLayout.wrap(
        heading: "Hi",
        body_html: "<p>x</p>",
        cta_url: "u",
        cta_label: "Go"
      )

    assert html =~ "logo-150.png"
    assert html =~ "Hi"
    assert html =~ "<p>x</p>"
    assert html =~ "1390 Chain Bridge Road"
  end

  test "renders pill_green title treatment" do
    html =
      EmailLayout.wrap(
        heading: "Great Peer Leadership",
        title_treatment: :pill_green,
        body_html: "<p></p>",
        cta_url: nil,
        cta_label: nil
      )

    assert html =~ "background:#dff5e0"
    assert html =~ "Great Peer Leadership"
  end

  test "skips CTA block when url is nil" do
    html =
      EmailLayout.wrap(
        heading: "h",
        body_html: "<p></p>",
        cta_url: nil,
        cta_label: "Go"
      )

    refute html =~ "border-radius:9999px"
  end

  test "skips CTA block when label is nil" do
    html =
      EmailLayout.wrap(
        heading: "h",
        body_html: "<p></p>",
        cta_url: "u",
        cta_label: nil
      )

    refute html =~ "border-radius:9999px"
  end

  test "renders hero icon emoji when provided" do
    html =
      EmailLayout.wrap(
        heading: "h",
        body_html: "<p></p>",
        hero_icon: "👋",
        cta_url: nil,
        cta_label: nil
      )

    assert html =~ "👋"
  end

  test "outer background is the orange gradient" do
    html =
      EmailLayout.wrap(
        heading: "h",
        body_html: "<p></p>",
        cta_url: nil,
        cta_label: nil
      )

    assert html =~ "linear-gradient(135deg,#e85d3a 0%,#f29554 100%)"
  end
end
