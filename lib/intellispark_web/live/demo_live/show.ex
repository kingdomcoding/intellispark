defmodule IntellisparkWeb.DemoLive.Show do
  use IntellisparkWeb, :live_view

  @personas [
    %{
      key: :district_admin,
      title: "District admin",
      blurb:
        "Full PRO-tier access at Sandbox High. See the Risk Dashboard, manage interventions, run integrations, access AshAdmin and LiveDashboard at /admin."
    },
    %{
      key: :counselor,
      title: "Counselor",
      blurb:
        "Scoped view at one school. Sees only their team's students; can't transfer students or manage integrations."
    },
    %{
      key: :xello_embed,
      title: "Xello embed",
      blurb:
        "The public-iframe surface a Xello partner sees. No auth chrome; just the embedded student profile."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Pick a demo persona — Intellispark")
     |> assign(:personas, @personas)
     |> assign(:signed_in?, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.public flash={@flash} signed_in?={@signed_in?}>
      <section class="mx-auto max-w-3xl px-md py-2xl">
        <h1 class="text-3xl font-bold text-abbey">Pick a demo persona</h1>
        <p class="mt-sm text-azure">
          One click signs you into the running app as that role. No forms. No email.
          The sandbox resets daily.
        </p>

        <div class="mt-xl grid gap-md sm:grid-cols-3">
          <div
            :for={p <- @personas}
            class="rounded-md border border-abbey/10 bg-white p-md flex flex-col"
          >
            <h2 class="text-lg font-semibold text-abbey">{p.title}</h2>
            <p class="mt-xs text-sm text-azure flex-1">{p.blurb}</p>
            <form action={~p"/demo/#{p.key}"} method="post" class="mt-md">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <button
                type="submit"
                class="w-full px-md py-sm rounded-md bg-brand text-white font-medium hover:bg-brand-700"
              >
                Open as {p.title} →
              </button>
            </form>
          </div>
        </div>
      </section>
    </Layouts.public>
    """
  end
end
