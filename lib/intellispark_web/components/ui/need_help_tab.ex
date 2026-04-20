defmodule IntellisparkWeb.UI.NeedHelpTab do
  use Phoenix.Component

  def need_help_tab(assigns) do
    ~H"""
    <a
      href="mailto:support@intellispark.local"
      class="fixed right-0 top-1/2 -translate-y-1/2 z-40 bg-chocolate text-white px-sm py-md rounded-l-card shadow-elevated"
      style="writing-mode: vertical-rl; transform: translateY(-50%) rotate(180deg);"
    >
      Need help?
    </a>
    """
  end
end
