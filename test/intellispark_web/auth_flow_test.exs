defmodule IntellisparkWeb.AuthFlowTest do
  use IntellisparkWeb.ConnCase, async: false

  alias Intellispark.Accounts.User

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    :ok
  end

  describe "register → confirm → sign in (via Ash actions, not the LiveView)" do
    test "happy path issues a confirmation email and lets the user sign in" do
      email = "newuser-#{System.unique_integer([:positive])}@sandboxhigh.edu"
      password = "brand-new-pass"

      {:ok, user} =
        Ash.create(
          User,
          %{email: email, password: password, password_confirmation: password},
          action: :register_with_password,
          authorize?: false
        )

      assert user.confirmed_at == nil

      assert_received {:email, %Swoosh.Email{} = confirmation_email}
      token = extract_confirm_token(confirmation_email)
      assert is_binary(token)

      {:ok, confirmed} =
        Ash.update(user, %{confirm: token}, action: :confirm, authorize?: false)

      refute is_nil(confirmed.confirmed_at)

      assert {:ok, [signed_in]} = sign_in(email, password)
      assert signed_in.id == user.id
    end

    test "password reset flow" do
      email = "reset-#{System.unique_integer([:positive])}@sandboxhigh.edu"
      old_password = "old-password-1"
      new_password = "new-password-2"

      {:ok, user} =
        Ash.create(
          User,
          %{email: email, password: old_password, password_confirmation: old_password},
          action: :register_with_password,
          authorize?: false
        )

      {:ok, _} =
        User
        |> Ash.Query.for_read(:request_password_reset_with_password, %{email: email})
        |> Ash.read(authorize?: false)

      assert_received {:email, %Swoosh.Email{} = _confirm_email}
      assert_received {:email, %Swoosh.Email{} = reset_email}
      reset_token = extract_reset_token(reset_email)
      assert is_binary(reset_token)

      {:ok, _} =
        Ash.update(
          user,
          %{
            reset_token: reset_token,
            password: new_password,
            password_confirmation: new_password
          },
          action: :password_reset_with_password,
          authorize?: false
        )

      assert {:ok, [_]} = sign_in(email, new_password)
      assert {:error, _} = sign_in(email, old_password)
    end
  end

  describe "sign-in LiveView" do
    test "GET /sign-in returns 200 and renders the password sign-in form", %{conn: conn} do
      conn = get(conn, ~p"/sign-in")
      body = html_response(conn, 200)
      assert body =~ "/auth/user/password/sign_in"
      assert body =~ "logo-horizontal.png"
    end
  end

  defp sign_in(email, password) do
    User
    |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: password})
    |> Ash.read(authorize?: false)
  end

  defp extract_confirm_token(%Swoosh.Email{text_body: body}) do
    case Regex.run(~r|/confirm_new_user/([^\s"]+)|, body) do
      [_, token] -> token
      _ -> nil
    end
  end

  defp extract_reset_token(%Swoosh.Email{text_body: body}) do
    case Regex.run(~r|/password-reset/([^\s"]+)|, body) do
      [_, token] -> token
      _ -> nil
    end
  end
end
