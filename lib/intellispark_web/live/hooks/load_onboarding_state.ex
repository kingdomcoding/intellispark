defmodule IntellisparkWeb.LiveHooks.LoadOnboardingState do
  @moduledoc """
  on_mount hook that assigns `:onboarding_incomplete?` for the current
  user + school pair. Only district admins see a truthy value. Reads the
  `SchoolOnboardingState` loaded onto the current_school (via the
  LiveUserAuth loader's `load: [:onboarding_state]` option) so there's
  no extra DB round-trip per mount.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    incomplete? =
      with %{} = user <- socket.assigns[:current_user],
           true <- district_admin?(user),
           %{} = school <- socket.assigns[:current_school],
           %{current_step: step, completed_at: completed_at} <-
             Map.get(school, :onboarding_state) do
        step != :done and is_nil(completed_at)
      else
        _ -> false
      end

    {:cont, assign(socket, :onboarding_incomplete?, incomplete?)}
  end

  defp district_admin?(user) do
    user.district_id != nil and
      Enum.any?(user.school_memberships || [], &(&1.role == :admin))
  end
end
