defmodule IntellisparkWeb.LandingLive.Show do
  use IntellisparkWeb, :live_view

  alias Intellispark.Landing.{BuildInfo, TestStats}

  @fallback_phase_count 22
  @fallback_test_count 554

  @impl true
  def mount(_params, _session, socket) do
    stats = TestStats.read()
    tags = BuildInfo.phase_tags()

    phase_count =
      case tags do
        list when is_list(list) and list != [] -> length(list)
        _ -> @fallback_phase_count
      end

    test_count =
      case stats["passing"] do
        n when is_integer(n) and n > 0 -> n
        _ -> @fallback_test_count
      end

    {:ok,
     socket
     |> assign(:page_title, "Intellispark — Elixir/Phoenix/Ash portfolio")
     |> assign(:proof, %{tests: test_count, phases: phase_count, adrs: adr_count()})
     |> assign(:signed_in?, false)}
  end

  defp adr_count do
    Path.wildcard("docs/architecture/decisions/*.md") |> length()
  end
end
