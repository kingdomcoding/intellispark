defmodule IntellisparkWeb.UI.Modal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :title, required: true
  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="fixed inset-0 bg-abbey/40 transition-opacity" aria-hidden="true">
      </div>
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-modal="true"
        role="dialog"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-xs">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class="relative w-full max-w-(--container-sm) rounded-card bg-white shadow-prominent"
          >
            <header class="flex items-center justify-between border-b border-lightgrey px-md py-sm">
              <h2 id={"#{@id}-title"} class="text-xl font-semibold">
                {render_slot(@title)}
              </h2>
              <button
                type="button"
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                aria-label="Close"
                class="text-azure hover:text-abbey"
              >
                <span class="hero-x-mark"></span>
              </button>
            </header>
            <div class="px-md py-sm">{render_slot(@inner_block)}</div>
            <footer
              :if={@footer != []}
              class="flex items-center justify-end gap-sm border-t border-lightgrey px-md py-sm"
            >
              {render_slot(@footer)}
            </footer>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  def show_modal(id) when is_binary(id) do
    %JS{}
    |> JS.show(
      to: "##{id}",
      transition: {"transition-all ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-bg",
      transition: {"ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_modal(id) when is_binary(id) do
    %JS{}
    |> JS.hide(
      to: "##{id}",
      transition: {"transition-all ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.pop_focus()
  end
end
