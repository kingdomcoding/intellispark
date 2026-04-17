defmodule Intellispark.Test.PolicyAudit do
  @moduledoc """
  Introspects every resource in every domain and reports which ones lack
  policy coverage. Wired into `test/policy_audit_test.exs` so the suite fails
  if a new resource ships without policies — critical for FERPA posture.
  """

  def all_resources do
    :intellispark
    |> Application.get_env(:ash_domains, [])
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
  end

  def resources_without_policies do
    all_resources()
    |> Enum.reject(&has_policies?/1)
  end

  defp has_policies?(resource) do
    Ash.Policy.Info.policies(resource) != []
  end
end
