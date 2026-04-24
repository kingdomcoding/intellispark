defmodule IntellisparkWeb.LandingLive.Show do
  use IntellisparkWeb, :live_view

  alias Intellispark.Landing.{BuildInfo, TestStats}

  @fallback_phase_count 22
  @fallback_test_count 564
  @fallback_adr_count 23

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

    adr_count =
      case BuildInfo.adr_count() do
        n when is_integer(n) and n > 0 -> n
        _ -> @fallback_adr_count
      end

    {:ok,
     socket
     |> assign(:page_title, "Intellispark — Elixir/Phoenix/Ash portfolio")
     |> assign(:proof, %{tests: test_count, phases: phase_count, adrs: adr_count})
     |> assign(:last_commit, BuildInfo.last_commit_short())
     |> assign(:commit_subject, BuildInfo.commit_subject())
     |> assign(:commit_timestamp, BuildInfo.commit_timestamp())
     |> assign(:signed_in?, false)}
  end
end
