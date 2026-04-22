defmodule Intellispark.Recognition.Changes.SanitizeBody do
  @moduledoc """
  Sanitizes HighFive `:body` on write so only safe rich-text tags survive
  (p, strong, em, u, br, ul, ol, li, a). Defense-in-depth alongside the
  RichTextEditor hook — a crafted request can bypass the hook, never the
  change module.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :body) do
      nil ->
        changeset

      "" ->
        changeset

      body when is_binary(body) ->
        clean = HtmlSanitizeEx.basic_html(body)
        Ash.Changeset.force_change_attribute(changeset, :body, clean)

      _ ->
        changeset
    end
  end
end
