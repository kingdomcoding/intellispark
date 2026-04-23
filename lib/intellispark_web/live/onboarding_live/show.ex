defmodule IntellisparkWeb.OnboardingLive.Show do
  @moduledoc """
  /onboarding — district-admin-only six-step wizard. Walks through
  school profile confirmation, co-admin invites, starter tags +
  statuses, SIS provider stub, tier pick, and a done screen. Persists
  progress in SchoolOnboardingState; each step is skippable.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Accounts
  alias Intellispark.Billing

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    school = socket.assigns[:current_school]

    cond do
      school == nil ->
        {:ok,
         socket
         |> put_flash(:error, "Pick a school first.")
         |> push_navigate(to: ~p"/students")}

      not district_admin?(user) ->
        {:ok,
         socket
         |> put_flash(:error, "Onboarding is for district admins.")
         |> push_navigate(to: ~p"/students")}

      true ->
        state = Billing.get_onboarding_state_by_school!(school.id, actor: user)

        {:ok,
         socket
         |> assign(
           page_title: "Get Started",
           state: state,
           step: state.current_step,
           error_message: nil
         )
         |> assign_step_form(state.current_step)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      onboarding_incomplete?={@onboarding_incomplete?}
    >
      <section class="container-lg py-xl space-y-md">
        <h1 class="text-display-md text-brand">Get Started</h1>

        <.step_tracker current_step={@step} />

        <div class="bg-white rounded-card shadow-card p-lg">
          <.step_body {assigns} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :current_step, :atom, required: true

  defp step_tracker(assigns) do
    ~H"""
    <ol class="flex flex-wrap items-center gap-sm text-xs">
      <.step_chip step={:school_profile} label="School profile" current={@current_step} />
      <.step_chip step={:invite_coadmins} label="Invite co-admins" current={@current_step} />
      <.step_chip step={:starter_tags} label="Starter tags" current={@current_step} />
      <.step_chip step={:sis_provider} label="Connect roster" current={@current_step} />
      <.step_chip step={:pick_tier} label="Pick a plan" current={@current_step} />
    </ol>
    """
  end

  attr :step, :atom, required: true
  attr :label, :string, required: true
  attr :current, :atom, required: true

  defp step_chip(assigns) do
    active? = assigns.step == assigns.current
    done? = ordinal(assigns.step) < ordinal(assigns.current)
    assigns = assign(assigns, active?: active?, done?: done?)

    ~H"""
    <li class={[
      "rounded-pill px-md py-1",
      @active? && "bg-brand/10 text-brand font-medium",
      @done? && "bg-status-resolved text-azure",
      !@active? && !@done? && "bg-whitesmoke text-azure"
    ]}>
      {@label}
    </li>
    """
  end

  attr :step, :atom, required: true
  attr :form, :any, default: nil
  attr :subscription_tier, :atom, default: :starter
  attr :error_message, :string, default: nil
  attr :current_school, :map, required: true

  defp step_body(%{step: :school_profile} = assigns) do
    ~H"""
    <div class="space-y-md">
      <div>
        <h2 class="text-lg font-semibold text-abbey">School profile</h2>
        <p class="text-sm text-azure">Confirm your school details. You can edit them later.</p>
      </div>

      <.form
        for={@form}
        phx-submit="submit_school_profile"
        id="onboarding-school-profile-form"
        class="space-y-md"
      >
        <.input field={@form[:name]} label="School name" />
        <.input field={@form[:slug]} label="URL slug" />

        <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

        <div class="flex justify-end gap-sm">
          <.button type="button" variant={:ghost} phx-click="skip_step">Skip</.button>
          <.button type="submit" variant={:primary}>Save &amp; continue</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp step_body(%{step: :invite_coadmins} = assigns) do
    ~H"""
    <div class="space-y-md">
      <div>
        <h2 class="text-lg font-semibold text-abbey">Invite co-admins</h2>
        <p class="text-sm text-azure">Send an invite to a teammate (you can add more later).</p>
      </div>

      <.form
        for={@form}
        phx-submit="submit_invite"
        id="onboarding-invite-form"
        class="space-y-md"
      >
        <.input field={@form[:email]} type="email" label="Email" />
        <.input
          field={@form[:role]}
          type="select"
          label="Role"
          options={[{"Admin", "admin"}, {"Counselor", "counselor"}]}
        />

        <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

        <div class="flex justify-end gap-sm">
          <.button type="button" variant={:ghost} phx-click="skip_step">Skip</.button>
          <.button type="submit" variant={:primary}>Invite &amp; continue</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp step_body(%{step: :starter_tags} = assigns) do
    ~H"""
    <div class="space-y-md">
      <div>
        <h2 class="text-lg font-semibold text-abbey">Starter tags &amp; statuses</h2>
        <p class="text-sm text-azure">
          We'll seed common defaults — "At risk", "Watch", "Doing well" — so you have something to filter students by.
        </p>
      </div>

      <div class="flex justify-end gap-sm">
        <.button type="button" variant={:ghost} phx-click="skip_step">Skip</.button>
        <.button type="button" variant={:primary} phx-click="seed_tags_and_statuses">
          Create defaults &amp; continue
        </.button>
      </div>
    </div>
    """
  end

  defp step_body(%{step: :sis_provider} = assigns) do
    ~H"""
    <div class="space-y-md">
      <div>
        <h2 class="text-lg font-semibold text-abbey">Connect a roster source</h2>
        <p class="text-sm text-azure">
          SIS integrations arrive in Phase 11. Skip for now — you can import students manually from the Students page.
        </p>
      </div>

      <div class="flex justify-end gap-sm">
        <.button type="button" variant={:primary} phx-click="skip_step">Continue</.button>
      </div>
    </div>
    """
  end

  defp step_body(%{step: :pick_tier} = assigns) do
    ~H"""
    <div class="space-y-md">
      <div>
        <h2 class="text-lg font-semibold text-abbey">Pick a plan</h2>
        <p class="text-sm text-azure">
          You can change this any time in Settings. Paid plans become interactive once billing ships.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-md">
        <.tier_card tier={:starter} current_tier={@subscription_tier} />
        <.tier_card tier={:plus} current_tier={@subscription_tier} />
        <.tier_card tier={:pro} current_tier={@subscription_tier} />
      </div>

      <div class="flex justify-end gap-sm">
        <.button type="button" variant={:ghost} phx-click="skip_step">Skip for now</.button>
      </div>
    </div>
    """
  end

  defp step_body(%{step: :done} = assigns) do
    ~H"""
    <div class="text-center py-lg space-y-md">
      <h2 class="text-xl font-semibold text-abbey">You're set up.</h2>
      <p class="text-sm text-azure">Head to your students list to get going.</p>
      <.button navigate={~p"/students"} variant={:primary}>View students</.button>
    </div>
    """
  end

  attr :tier, :atom, required: true
  attr :current_tier, :atom, required: true

  defp tier_card(assigns) do
    selected? = assigns.tier == assigns.current_tier
    assigns = assign(assigns, selected?: selected?)

    ~H"""
    <button
      type="button"
      phx-click="choose_tier"
      phx-value-tier={to_string(@tier)}
      class={[
        "text-left rounded-card p-md border-2 transition",
        @selected? && "border-brand bg-brand/5",
        !@selected? && "border-abbey/20 hover:border-brand"
      ]}
    >
      <p class="text-lg font-semibold text-abbey">{Intellispark.Tiers.label(@tier)}</p>
      <p class="text-xs text-azure mt-xs">{tier_pitch(@tier)}</p>
    </button>
    """
  end

  defp tier_pitch(:starter), do: "Up to 5 custom lists, no automation, no Xello."
  defp tier_pitch(:plus), do: "50 custom lists, up to 25 automation rules."
  defp tier_pitch(:pro), do: "Unlimited lists, Xello embed, Insights export, API."

  @impl true
  def handle_event("skip_step", _params, socket), do: advance(socket)

  def handle_event("submit_school_profile", %{"school" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _school} ->
        advance(socket)

      {:error, form} ->
        {:noreply,
         assign(socket,
           form: form,
           error_message: "Could not save — check the fields and try again."
         )}
    end
  end

  def handle_event("submit_invite", %{"invite" => params}, socket) do
    case send_invite(socket, params) do
      {:ok, _invite} ->
        advance(socket)

      {:error, reason} ->
        {:noreply, assign(socket, error_message: reason)}
    end
  end

  def handle_event("seed_tags_and_statuses", _params, socket) do
    seed_tags_and_statuses(socket)
    advance(socket)
  end

  def handle_event("choose_tier", %{"tier" => tier_str}, socket) do
    tier = String.to_existing_atom(tier_str)
    sub = socket.assigns.current_school.subscription

    {:ok, _updated} =
      Billing.set_tier(sub, tier,
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_school.id
      )

    advance(
      socket
      |> assign(subscription_tier: tier)
    )
  end

  defp advance(socket) do
    next = next_step(socket.assigns.step)

    {:ok, state} =
      case next do
        :done ->
          Billing.complete_onboarding(socket.assigns.state,
            actor: socket.assigns.current_user,
            tenant: socket.assigns.current_school.id
          )

        other ->
          Billing.advance_onboarding_step(socket.assigns.state, other,
            actor: socket.assigns.current_user,
            tenant: socket.assigns.current_school.id
          )
      end

    {:noreply,
     socket
     |> assign(state: state, step: state.current_step, error_message: nil)
     |> assign_step_form(state.current_step)}
  end

  defp next_step(:school_profile), do: :invite_coadmins
  defp next_step(:invite_coadmins), do: :starter_tags
  defp next_step(:starter_tags), do: :sis_provider
  defp next_step(:sis_provider), do: :pick_tier
  defp next_step(:pick_tier), do: :done
  defp next_step(:done), do: :done

  defp ordinal(:school_profile), do: 0
  defp ordinal(:invite_coadmins), do: 1
  defp ordinal(:starter_tags), do: 2
  defp ordinal(:sis_provider), do: 3
  defp ordinal(:pick_tier), do: 4
  defp ordinal(:done), do: 5

  defp assign_step_form(socket, :school_profile) do
    school = socket.assigns.current_school

    form =
      school
      |> AshPhoenix.Form.for_update(:update,
        actor: socket.assigns.current_user,
        domain: Accounts,
        as: "school"
      )
      |> to_form()

    assign(socket,
      form: form,
      subscription_tier: subscription_tier(school)
    )
  end

  defp assign_step_form(socket, :invite_coadmins) do
    form = to_form(%{"email" => "", "role" => "counselor"}, as: "invite")

    assign(socket,
      form: form,
      subscription_tier: subscription_tier(socket.assigns.current_school)
    )
  end

  defp assign_step_form(socket, _step) do
    assign(socket,
      form: nil,
      subscription_tier: subscription_tier(socket.assigns.current_school)
    )
  end

  defp subscription_tier(%{subscription: %{tier: t}}), do: t
  defp subscription_tier(_), do: :starter

  defp send_invite(socket, %{"email" => email, "role" => role_str}) do
    role = String.to_existing_atom(role_str)
    school = socket.assigns.current_school
    actor = socket.assigns.current_user

    Intellispark.Accounts.SchoolInvitation
    |> Ash.Changeset.for_create(
      :invite,
      %{email: email, role: role, school_id: school.id},
      actor: actor
    )
    |> Ash.create()
    |> case do
      {:ok, invite} -> {:ok, invite}
      {:error, _} -> {:error, "Invitation failed — check the email address."}
    end
  end

  defp seed_tags_and_statuses(socket) do
    school = socket.assigns.current_school
    actor = socket.assigns.current_user

    for preset <- [
          %{name: "At risk", color: "#D94A4A"},
          %{name: "Watch", color: "#E59F42"},
          %{name: "Doing well", color: "#3AAE5F"}
        ] do
      Intellispark.Students.Tag
      |> Ash.Changeset.for_create(:create, preset, tenant: school.id, actor: actor)
      |> Ash.create(authorize?: false)
    end

    for {preset, idx} <-
          Enum.with_index([
            %{name: "Flagged", color: "#D94A4A"},
            %{name: "In review", color: "#E59F42"},
            %{name: "Resolved", color: "#3AAE5F"}
          ]) do
      Intellispark.Students.Status
      |> Ash.Changeset.for_create(:create, Map.put(preset, :position, idx),
        tenant: school.id,
        actor: actor
      )
      |> Ash.create(authorize?: false)
    end

    :ok
  end

  defp district_admin?(nil), do: false

  defp district_admin?(user) do
    user.district_id != nil and
      Enum.any?(user.school_memberships || [], &(&1.role == :admin))
  end
end
