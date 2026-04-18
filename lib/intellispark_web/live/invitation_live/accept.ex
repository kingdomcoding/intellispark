defmodule IntellisparkWeb.InvitationLive.Accept do
  @moduledoc """
  Public-facing page rendered from the link in a SchoolInvitation email.
  Loads the invitation by id, routes into one of four states:

    * `:ready`            — pending invite, render password-setup form
    * `{:error, :accepted}`
    * `{:error, :revoked}`
    * `{:error, :invalid}` — unknown id or expired

  On submit of a valid form the invitation is accepted (user + membership
  created atomically) and the browser is redirected to AshAuthentication's
  sign_in_with_token endpoint so the session cookie gets established via
  the standard AuthController.success path.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Accounts
  alias Intellispark.Accounts.SchoolInvitation

  @impl true
  def mount(%{"token" => id}, _session, socket) do
    socket = assign(socket, page_title: "Accept invitation", form: empty_form())

    case load_invitation(id) do
      {:ok, %{status: :pending} = invitation} ->
        invitation = Ash.load!(invitation, [:school], authorize?: false)

        if expired?(invitation) do
          {:ok, assign(socket, state: {:error, :invalid}, invitation: nil)}
        else
          {:ok, assign(socket, state: :ready, token: id, invitation: invitation)}
        end

      {:ok, %{status: status}} ->
        {:ok, assign(socket, state: {:error, status}, invitation: nil)}

      _ ->
        {:ok, assign(socket, state: {:error, :invalid}, invitation: nil)}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    invitation = socket.assigns.invitation

    case Accounts.accept_school_invitation(
           invitation,
           params["password"] || "",
           params["password_confirmation"] || "",
           nil_if_blank(params["first_name"]),
           nil_if_blank(params["last_name"]),
           authorize?: false
         ) do
      {:ok, accepted} ->
        redirect_after_accept(socket, accepted)

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, humanize_error(error))
         |> assign(form: to_form(params, as: :user))}
    end
  end

  defp load_invitation(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _} -> Ash.get(SchoolInvitation, id, authorize?: false)
      :error -> :error
    end
  end

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) != :gt
  end

  defp redirect_after_accept(socket, accepted) do
    user = accepted.__metadata__[:user]
    school_name = accepted.__metadata__[:school_name] || accepted.school.name

    case user && user.__metadata__[:token] do
      token when is_binary(token) ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome to #{school_name}!")
         |> redirect(to: ~p"/auth/user/password/sign_in_with_token?token=#{token}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Welcome to #{school_name}! Sign in with your account to continue."
         )
         |> redirect(to: ~p"/sign-in")}
    end
  end

  defp humanize_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map_join("; ", & &1.message)
    |> case do
      "" -> "We couldn't accept this invitation. Please try again."
      msg -> msg
    end
  end

  defp humanize_error(_), do: "We couldn't accept this invitation. Please try again."

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(""), do: nil
  defp nil_if_blank(value) when is_binary(value), do: String.trim(value)

  defp empty_form do
    to_form(
      %{
        "first_name" => "",
        "last_name" => "",
        "password" => "",
        "password_confirmation" => ""
      },
      as: :user
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="min-h-[calc(100vh-4rem)] flex justify-center items-start pt-xl px-xs">
        <div class="w-full max-w-[28rem] rounded-card bg-white shadow-card p-lg space-y-md">
          <%= case @state do %>
            <% :ready -> %>
              <div>
                <h1 class="text-display-sm text-navy">Welcome to Intellispark</h1>
                <p class="text-abbey mt-xs">
                  You're joining <strong>{@invitation.school.name}</strong>
                  as a <strong>{@invitation.role}</strong>. Set a password to finish.
                </p>
              </div>

              <.form for={@form} phx-submit="submit" id="accept-form" class="space-y-sm">
                <div>
                  <label class="sr-only">Email</label>
                  <input
                    type="email"
                    value={@invitation.email}
                    disabled
                    class="w-full rounded-lg border border-abbey/20 px-3 py-2 bg-whitesmoke text-abbey"
                  />
                </div>

                <div class="grid grid-cols-2 gap-sm">
                  <.input field={@form[:first_name]} type="text" placeholder="First name" />
                  <.input field={@form[:last_name]} type="text" placeholder="Last name" />
                </div>

                <.input
                  field={@form[:password]}
                  type="password"
                  placeholder="Set password"
                  required
                />
                <.input
                  field={@form[:password_confirmation]}
                  type="password"
                  placeholder="Confirm password"
                  required
                />

                <.button variant={:primary} type="submit" class="w-full">
                  Accept &amp; create account
                </.button>
              </.form>

            <% {:error, :accepted} -> %>
              <.invitation_error
                title="Already accepted"
                message="This invitation has already been used. If you already have an account, sign in instead."
              />

            <% {:error, :revoked} -> %>
              <.invitation_error
                title="Invitation cancelled"
                message="This invitation was revoked. Contact your administrator for a new invite."
              />

            <% _ -> %>
              <.invitation_error
                title="Link invalid or expired"
                message="This invitation link is no longer valid. Ask your administrator to resend it."
              />
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :message, :string, required: true

  defp invitation_error(assigns) do
    ~H"""
    <h1 class="text-display-sm text-navy">{@title}</h1>
    <p class="text-abbey">{@message}</p>
    <.link
      navigate={~p"/sign-in"}
      class="inline-flex items-center text-brand hover:text-brand-700 font-medium"
    >
      Back to sign in
    </.link>
    """
  end
end
