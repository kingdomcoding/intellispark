defmodule IntellisparkWeb.StudentLive.Tabs do
  @moduledoc """
  Parses + serializes Hub tab state for the URL `?tab=` param. Pure module:
  no LV/Phoenix imports. Used by `StudentLive.Show.handle_params/3` to
  derive `@active_tab` and by `StudentLive.TabStrip` to build patch URLs.
  """

  @type tab :: :profile | :about | {:flag, String.t()} | {:support, String.t()}

  @spec from_param(String.t() | nil) :: tab()
  def from_param(nil), do: :profile
  def from_param(""), do: :profile
  def from_param("profile"), do: :profile
  def from_param("about"), do: :about
  def from_param("flag:" <> id), do: maybe_kind(:flag, id)
  def from_param("support:" <> id), do: maybe_kind(:support, id)
  def from_param(_), do: :profile

  @spec to_param(tab()) :: String.t()
  def to_param(:profile), do: "profile"
  def to_param(:about), do: "about"
  def to_param({:flag, id}), do: "flag:#{id}"
  def to_param({:support, id}), do: "support:#{id}"

  defp maybe_kind(kind, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {kind, uuid}
      :error -> :profile
    end
  end
end
