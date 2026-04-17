defmodule Intellispark.Accounts.PaperTrailTest do
  use Intellispark.DataCase, async: false

  alias Intellispark.Accounts.User

  test "updating a user creates version rows" do
    {:ok, user} =
      Ash.create(
        User,
        %{
          email: "pt@sandbox.edu",
          password: "irrelevant1",
          password_confirmation: "irrelevant1"
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, _} =
      Ash.update(user, %{first_name: "Initial"}, action: :update_profile, authorize?: false)

    {:ok, _} =
      Ash.update(user, %{first_name: "Updated"}, action: :update_profile, authorize?: false)

    {:ok, versions} = Ash.read(User.Version, authorize?: false)
    user_versions = Enum.filter(versions, &(&1.version_source_id == user.id))

    assert length(user_versions) >= 2
  end

  test "hashed_password is not persisted in version snapshots" do
    {:ok, user} =
      Ash.create(
        User,
        %{
          email: "pt-secret@sandbox.edu",
          password: "irrelevant2",
          password_confirmation: "irrelevant2"
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, _} =
      Ash.update(user, %{first_name: "X"}, action: :update_profile, authorize?: false)

    {:ok, versions} = Ash.read(User.Version, authorize?: false)
    user_versions = Enum.filter(versions, &(&1.version_source_id == user.id))

    Enum.each(user_versions, fn v ->
      changes = v.changes || %{}
      refute Map.has_key?(changes, "hashed_password")
      refute Map.has_key?(changes, :hashed_password)
    end)
  end
end
