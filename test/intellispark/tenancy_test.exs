defmodule Intellispark.TenancyTest do
  use ExUnit.Case, async: true

  alias Intellispark.Accounts.{School, UserSchoolMembership}
  alias Intellispark.Tenancy

  test "to_tenant raises on nil" do
    assert_raise ArgumentError, fn -> Tenancy.to_tenant(nil) end
  end

  test "normalizes a %School{} struct" do
    school = %School{id: "abc-123"}
    assert Tenancy.to_tenant(school) == "abc-123"
  end

  test "normalizes a school_id binary" do
    assert Tenancy.to_tenant("abc-123") == "abc-123"
  end

  test "normalizes a %UserSchoolMembership{}" do
    m = %UserSchoolMembership{school_id: "xyz-789"}
    assert Tenancy.to_tenant(m) == "xyz-789"
  end

  test "normalizes a map with :current_school" do
    assert Tenancy.to_tenant(%{current_school: %School{id: "from-map"}}) == "from-map"
  end

  test "raises on unrecognised input" do
    assert_raise ArgumentError, fn -> Tenancy.to_tenant(%{foo: :bar}) end
  end
end
