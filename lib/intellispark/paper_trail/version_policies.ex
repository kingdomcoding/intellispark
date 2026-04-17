defmodule Intellispark.PaperTrail.VersionPolicies do
  @moduledoc """
  Mixin used by every AshPaperTrail-generated `.Version` resource. Denies all
  external access by default — version rows are internal audit storage.
  Admin tooling that needs to read versions does so with `authorize?: false`.
  """

  defmacro __using__(_opts) do
    quote do
      policies do
        bypass AshAuthentication.Checks.AshAuthenticationInteraction do
          authorize_if always()
        end

        policy always() do
          authorize_if never()
        end
      end
    end
  end
end
