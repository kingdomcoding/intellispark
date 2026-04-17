defmodule IntellisparkWeb.UI.Card do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :count, :integer, default: nil
  attr :add_label, :string, default: nil
  attr :on_add, :string, default: nil
  attr :variant, :atom, default: :white, values: [:white, :navy]
  attr :class, :string, default: nil
  slot :header_extra
  slot :inner_block, required: true
  slot :empty_state

  def section(assigns) do
    ~H"""
    <section class={[
      "rounded-card shadow-card p-md",
      @variant == :white && "bg-white",
      @variant == :navy && "bg-navy text-white",
      @class
    ]}>
      <header class="flex items-center justify-between mb-sm">
        <div class="flex items-center gap-1">
          <h2 class={[
            "text-lg font-semibold",
            @variant == :navy && "text-white"
          ]}>
            {@title}
            <span :if={@count} class="font-normal opacity-70">({@count})</span>
          </h2>
          {render_slot(@header_extra)}
        </div>
        <.add_button :if={@add_label} label={@add_label} variant={@variant} phx-click={@on_add} />
      </header>
      {render_slot(@inner_block)}
      {render_slot(@empty_state)}
    </section>
    """
  end

  attr :label, :string, required: true
  attr :variant, :atom, default: :white, values: [:white, :navy]
  attr :rest, :global, include: ~w(phx-click phx-value-id navigate)

  def add_button(assigns) do
    ~H"""
    <button
      class={[
        "inline-flex items-center gap-1 rounded-pill border px-4 py-1.5 text-sm font-medium transition-colors",
        @variant == :white && "bg-white text-brand border-brand/20 hover:border-brand hover:bg-brand/5",
        @variant == :navy && "bg-transparent text-white border-white/40 hover:border-white hover:bg-white/10"
      ]}
      {@rest}
    >
      <span class="hero-plus-mini"></span>
      {@label}
    </button>
    """
  end
end
