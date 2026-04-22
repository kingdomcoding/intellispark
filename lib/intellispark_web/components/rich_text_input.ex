defmodule IntellisparkWeb.Components.RichTextInput do
  @moduledoc """
  Rich-text body input. Renders a contenteditable `<div>` plus a
  toolbar (bold / italic / underline / unordered list / ordered list)
  and a hidden form input mirrored by the `RichTextEditor` JS hook.
  """

  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :label, :string, default: nil
  attr :placeholder, :string, default: ""
  attr :id, :string, default: nil

  def rich_text_input(assigns) do
    assigns =
      assign_new(assigns, :id, fn -> "rt-#{normalize_id(assigns.name)}" end)

    ~H"""
    <div phx-hook="RichTextEditor" id={@id} class="space-y-0" phx-update="ignore">
      <label
        :if={@label}
        class="block text-sm font-medium text-abbey mb-xs"
        for={"#{@id}-editor"}
      >
        {@label}
      </label>

      <div class="rounded border border-abbey/20 overflow-hidden bg-white">
        <div class="flex items-center gap-xs border-b border-abbey/10 px-sm py-1 bg-whitesmoke">
          <.toolbar_btn command="bold" label="Bold" icon="B" weight={:bold} />
          <.toolbar_btn command="italic" label="Italic" icon="I" weight={:italic} />
          <.toolbar_btn command="underline" label="Underline" icon="U" weight={:underline} />
          <span class="w-px h-4 bg-abbey/20 mx-xs"></span>
          <.toolbar_btn command="insertUnorderedList" label="Bulleted list" icon="•" />
          <.toolbar_btn command="insertOrderedList" label="Numbered list" icon="1." />
        </div>

        <div
          id={"#{@id}-editor"}
          data-rt-editor
          contenteditable="true"
          role="textbox"
          aria-multiline="true"
          aria-label={@label || @name}
          data-placeholder={@placeholder}
          class="min-h-[6rem] p-sm text-sm text-abbey focus:outline-none empty:before:content-[attr(data-placeholder)] empty:before:text-azure/50"
        ></div>

        <input type="hidden" name={@name} value={@value} data-rt-input />
      </div>
    </div>
    """
  end

  attr :command, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :weight, :atom, default: nil, values: [nil, :bold, :italic, :underline]

  defp toolbar_btn(assigns) do
    ~H"""
    <button
      type="button"
      data-rt-command={@command}
      aria-label={@label}
      title={@label}
      class={[
        "inline-flex items-center justify-center min-w-[1.75rem] h-7 rounded text-sm text-abbey hover:bg-abbey/10",
        @weight == :bold && "font-bold",
        @weight == :italic && "italic",
        @weight == :underline && "underline"
      ]}
    >
      {@icon}
    </button>
    """
  end

  defp normalize_id(name) do
    name
    |> String.replace(~r/[^\w-]/, "-")
    |> String.trim("-")
  end
end
