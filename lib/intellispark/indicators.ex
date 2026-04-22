defmodule Intellispark.Indicators do
  @moduledoc """
  Domain for SEL dimension indicators (Phase 8). Holds IndicatorScore
  + the scoring algorithm + the recompute mix task. The 13 dimensions
  themselves live as a plain module constant at
  `Intellispark.Indicators.Dimension`.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
  end
end
