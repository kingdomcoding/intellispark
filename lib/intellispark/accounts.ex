defmodule Intellispark.Accounts do
  use Ash.Domain, otp_app: :intellispark

  resources do
    # Resources added in later phases — each wrapped with a `define` block
    # that exposes its code interface on the domain (Convention B).
  end
end
