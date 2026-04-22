defmodule Intellispark.Billing do
  @moduledoc """
  Per-school subscription tier + onboarding state. Phase 18.5 introduces
  `SchoolSubscription` (tier + billing status, one per school) and
  `SchoolOnboardingState` (wizard progress). Future Stripe integration
  extends SchoolSubscription with `stripe_subscription_id`; webhook
  handlers will update `tier` and `status` atomically.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Billing.SchoolSubscription do
      define :get_subscription_by_school,
        action: :read,
        get_by: [:school_id],
        get?: true

      define :set_tier, action: :set_tier, args: [:tier]
      define :list_subscriptions, action: :read
    end

    resource Intellispark.Billing.SchoolSubscription.Version

    resource Intellispark.Billing.SchoolOnboardingState do
      define :get_onboarding_state_by_school,
        action: :read,
        get_by: [:school_id],
        get?: true

      define :advance_onboarding_step, action: :advance_step, args: [:step]
      define :complete_onboarding, action: :complete
    end

    resource Intellispark.Billing.SchoolOnboardingState.Version
  end
end
