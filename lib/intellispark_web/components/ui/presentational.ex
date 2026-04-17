defmodule IntellisparkWeb.UI.Presentational do
  use Phoenix.Component

  attr :message, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class={["text-center py-lg text-azure italic", @class]}>
      <span :if={@icon} class={[@icon, "mx-auto mb-2 text-azure"]}></span>
      <p>{@message}</p>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :image_url, :string, default: nil
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil

  def avatar(%{image_url: url} = assigns) when is_binary(url) do
    ~H"""
    <img
      src={@image_url}
      alt={@name}
      class={["rounded-full object-cover", size_classes(@size), @class]}
    />
    """
  end

  def avatar(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center justify-center rounded-full bg-brand-100 text-brand-700 font-medium",
        size_classes(@size),
        @class
      ]}
      aria-label={@name}
      title={@name}
    >
      {initials(@name)}
    </span>
    """
  end

  defp size_classes(:sm), do: "h-8 w-8 text-xs"
  defp size_classes(:md), do: "h-10 w-10 text-sm"
  defp size_classes(:lg), do: "h-14 w-14 text-base"

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
end
