defmodule Intellispark.Integrations do
  @moduledoc """
  SIS + Xello integration resources. IntegrationProvider holds per-school
  encrypted credentials; IntegrationSyncRun tracks sync lifecycle via a
  state machine; IntegrationSyncError is the dead-letter log.
  XelloProfile is a per-student snapshot of Xello's profile data,
  upserted by webhook. EmbedToken authorizes the public
  `/embed/student/:token` view consumed by Xello iframes.
  """

  use Ash.Domain, otp_app: :intellispark, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Integrations.IntegrationProvider do
      define :list_providers, action: :read
      define :get_provider_by_id, action: :read, get_by: [:id]
      define :create_provider, action: :create
      define :update_provider_credentials, action: :update_credentials
      define :activate_provider, action: :activate
      define :deactivate_provider, action: :deactivate
      define :run_sync_now, action: :run_now
    end

    resource Intellispark.Integrations.IntegrationProvider.Version

    resource Intellispark.Integrations.IntegrationSyncRun do
      define :list_sync_runs, action: :read
      define :get_sync_run_by_id, action: :read, get_by: [:id]
      define :start_sync, action: :start
      define :succeed_sync, action: :succeed
      define :partial_succeed_sync, action: :partial_succeed
      define :fail_sync, action: :fail
    end

    resource Intellispark.Integrations.IntegrationSyncRun.Version

    resource Intellispark.Integrations.IntegrationSyncError do
      define :list_sync_errors, action: :read
      define :record_sync_error, action: :record
      define :retry_sync_error, action: :retry
      define :resolve_sync_error, action: :mark_resolved
    end

    resource Intellispark.Integrations.IntegrationSyncError.Version

    resource Intellispark.Integrations.XelloProfile do
      define :get_profile_by_student,
        action: :read,
        get_by: [:student_id],
        get?: true

      define :upsert_xello_profile, action: :upsert_from_webhook
    end

    resource Intellispark.Integrations.XelloProfile.Version

    resource Intellispark.Integrations.EmbedToken do
      define :get_embed_token, action: :by_token, args: [:token], get?: true
      define :list_embed_tokens, action: :read
      define :mint_embed_token, action: :mint
      define :regenerate_embed_token, action: :regenerate
      define :revoke_embed_token, action: :revoke
    end

    resource Intellispark.Integrations.EmbedToken.Version
  end
end
