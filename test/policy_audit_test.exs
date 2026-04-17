defmodule Intellispark.PolicyAuditTest do
  use ExUnit.Case, async: true

  alias Intellispark.Test.PolicyAudit

  test "every resource has policies defined" do
    offenders = PolicyAudit.resources_without_policies()

    assert offenders == [], """
    The following resources are missing a `policies` block:

    #{Enum.map_join(offenders, "\n", &"  - #{inspect(&1)}")}

    Add a `policies do ... end` block to each. For FERPA compliance, no resource
    should ship open-by-default.
    """
  end
end
