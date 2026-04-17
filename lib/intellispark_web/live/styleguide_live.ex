defmodule IntellisparkWeb.StyleguideLive do
  use IntellisparkWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Styleguide")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="container-lg py-xxl space-y-xxl">
        <header>
          <h1 class="text-display-md">
            Intellispark <span class="text-gradient-orange">Design System</span>
          </h1>
          <p class="text-lg mt-sm text-azure max-w-(--container-sm)">
            Visual reference for every reusable component. If something here doesn't match the
            Intellispark screenshots, it won't match in the features either &mdash; fix it here first.
          </p>
        </header>

        <section>
          <h2 class="text-display-sm mb-md">Colors</h2>
          <div class="grid grid-cols-4 gap-md">
            <.swatch name="Chocolate" hex="#f26a1b" class="bg-chocolate" />
            <.swatch name="Sandy" hex="#ef9640" class="bg-sandy" />
            <.swatch name="Orange-red" hex="#d9532a" class="bg-chocolate-600" />
            <.swatch name="Navy (Flags)" hex="#2b4366" class="bg-navy text-white" />
            <.swatch name="Brand Blue" hex="#1f8bb5" class="bg-brand text-white" />
            <.swatch name="Whitesmoke" hex="#f2f5f7" class="bg-whitesmoke" />
            <.swatch name="Cream" hex="#fff6e8" class="bg-cream" />
            <.swatch name="Abbey" hex="#4b4b4d" class="bg-abbey text-white" />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Typography</h2>
          <div class="space-y-md">
            <div><span class="text-display-xl">Display XL &mdash; 4.5rem</span></div>
            <div><span class="text-display-lg">Display LG &mdash; 3.75rem</span></div>
            <div><span class="text-display-md">Display MD &mdash; 3rem</span></div>
            <div><span class="text-display-sm">Display SM &mdash; 2.5rem</span></div>
            <div>
              <span class="text-lg font-semibold">Heading (lg semibold) &mdash; section titles</span>
            </div>
            <div><span class="text-base">Body regular &mdash; 16px</span></div>
            <div><span class="text-sm text-azure">Meta / gray text &mdash; 14px azure</span></div>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Buttons</h2>
          <div class="flex flex-wrap gap-sm items-center">
            <.button variant={:primary}>Book a Demo</.button>
            <.button variant={:secondary}>Secondary</.button>
            <.button variant={:blue}>Save</.button>
            <.button variant={:link}>Forgot password?</.button>
            <.button variant={:ghost} icon="hero-plus">Add</.button>
            <.button variant={:danger}>Delete</.button>
            <.button variant={:primary} loading={true}>Sending…</.button>
            <.button variant={:blue} disabled={true}>Disabled</.button>
          </div>
          <h3 class="text-lg font-semibold mt-md mb-sm">Sizes</h3>
          <div class="flex flex-wrap gap-sm items-center">
            <.button variant={:primary} size={:sm}>Small</.button>
            <.button variant={:primary} size={:md}>Medium</.button>
            <.button variant={:primary} size={:lg}>Large</.button>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Add Buttons</h2>
          <div class="flex gap-sm">
            <.add_button label="High 5" />
            <.add_button label="Flag" />
            <.add_button label="Strength" />
            <.add_button label="Team member" />
          </div>
          <div class="mt-md p-md bg-navy rounded-card">
            <.add_button label="Flag" variant={:navy} />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">
            Level Indicators <span class="text-base text-azure">(Insights style &mdash; filled)</span>
          </h2>
          <div class="grid grid-cols-3 gap-md max-w-2xl">
            <.level_indicator level={:low} />
            <.level_indicator level={:moderate} />
            <.level_indicator level={:high} />
          </div>

          <h3 class="text-lg font-semibold mt-md mb-sm">Student Hub style &mdash; outlined</h3>
          <div class="grid grid-cols-3 gap-md max-w-2xl">
            <.level_indicator level={:low} filled={false} />
            <.level_indicator level={:moderate} filled={false} />
            <.level_indicator level={:high} filled={false} />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Status Badges</h2>
          <div class="flex gap-sm">
            <.status_badge label="SST - Followup" variant={:followup} />
            <.status_badge label="SST - Resolved" variant={:resolved} />
            <.status_badge label="Active" variant={:active} />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Tag Chips</h2>
          <div class="flex flex-wrap gap-sm">
            <.tag_chip label="Assistive Technology" removable={true} />
            <.tag_chip label="IEP" removable={true} />
            <.tag_chip label="1st Gen" removable={true} />
            <.tag_chip label="Academic Focus" />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Count Badges</h2>
          <div class="flex gap-sm items-center">
            <.count_badge value={4} variant={:high_fives} />
            <.count_badge value={4} variant={:flags} />
            <.count_badge value={2} variant={:supports} />
            <.count_badge value={0} variant={:neutral} />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Section Cards</h2>
          <div class="grid grid-cols-2 gap-md">
            <.section title="Strengths" count={5} add_label="Strength">
              <ul class="list-disc pl-5 text-abbey space-y-1">
                <li>Creativity</li>
                <li>Sense of humor</li>
                <li>Enjoys project based activities</li>
              </ul>
            </.section>

            <.section title="Flags" count={4} add_label="Flag" variant={:navy}>
              <.empty_state message="No flags raised yet." class="!text-white" />
            </.section>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Avatars</h2>
          <div class="flex gap-sm items-center">
            <.avatar name="Jason Baker" size={:sm} />
            <.avatar name="Jason Baker" size={:md} />
            <.avatar name="Jason Baker" size={:lg} />
            <.avatar name="Dan Morris" size={:md} />
          </div>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Modal</h2>
          <.button variant={:blue} phx-click={show_modal("demo-modal")}>Open modal</.button>

          <.modal id="demo-modal" on_cancel={hide_modal("demo-modal")}>
            <:title>New Flag</:title>
            <p class="text-abbey">Form fields go here. This is just a visual demo.</p>
            <:footer>
              <.button variant={:link} phx-click={hide_modal("demo-modal")}>Cancel</.button>
              <.button variant={:blue}>Save</.button>
            </:footer>
          </.modal>
        </section>

        <section>
          <h2 class="text-display-sm mb-md">Empty States</h2>
          <div class="space-y-sm max-w-xl">
            <.empty_state message="No course roster information added." />
            <.empty_state message="No family members added." icon="hero-user-group" />
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :name, :string, required: true
  attr :hex, :string, required: true
  attr :class, :string, required: true

  defp swatch(assigns) do
    ~H"""
    <div class="rounded-card shadow-card overflow-hidden">
      <div class={["h-20 p-sm flex items-end", @class]}>
        <span class="text-sm font-mono">{@hex}</span>
      </div>
      <div class="p-sm text-sm text-abbey">{@name}</div>
    </div>
    """
  end
end
