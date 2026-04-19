defmodule Intellispark.Resource do
  @moduledoc """
  Base module used by every resource in the Intellispark domain.

  Provides the default data layer, audit trail, archival, and notifier setup
  so individual resources only need to declare domain-specific concerns.
  """

  defmacro __using__(opts) do
    domain = Keyword.fetch!(opts, :domain)

    quote do
      use Ash.Resource,
        domain: unquote(domain),
        data_layer: AshPostgres.DataLayer,
        authorizers: [Ash.Policy.Authorizer],
        extensions: [
          AshPaperTrail.Resource,
          AshArchival.Resource,
          AshOban,
          AshAdmin.Resource
        ],
        notifiers: [Ash.Notifier.PubSub]

      paper_trail do
        change_tracking_mode :snapshot
        store_action_name? true
        ignore_attributes [:inserted_at, :updated_at]
        version_extensions authorizers: [Ash.Policy.Authorizer]
        mixin Intellispark.PaperTrail.VersionPolicies
      end

      pub_sub do
        module IntellisparkWeb.Endpoint
        prefix "resource"
        publish_all :create, ["created", :id]
        publish_all :update, ["updated", :id]
        publish_all :destroy, ["destroyed", :id]
      end
    end
  end
end
