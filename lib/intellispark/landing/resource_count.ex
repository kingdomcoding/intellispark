defmodule Intellispark.Landing.ResourceCount do
  @moduledoc """
  Counts Ash resources + lines of Elixir code in lib/ at app boot.
  Stable across deploys; cheap to compute once and serve from state.
  """

  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def resources, do: GenServer.call(__MODULE__, :resources)
  def loc, do: GenServer.call(__MODULE__, :loc)
  def domain_count, do: GenServer.call(__MODULE__, :domains)

  @impl true
  def init(:ok) do
    {:ok,
     %{
       resources: count_resources(),
       loc: count_loc(),
       domains: count_domains()
     }}
  end

  @impl true
  def handle_call(:resources, _from, s), do: {:reply, s.resources, s}
  def handle_call(:loc, _from, s), do: {:reply, s.loc, s}
  def handle_call(:domains, _from, s), do: {:reply, s.domains, s}

  defp count_resources do
    "lib/intellispark/**/*.ex"
    |> Path.wildcard()
    |> Enum.count(fn path ->
      case File.read(path) do
        {:ok, bin} ->
          String.contains?(bin, "use Ash.Resource") or
            String.contains?(bin, "use Intellispark.Resource")

        _ ->
          false
      end
    end)
  end

  defp count_loc do
    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.reduce(0, fn path, acc ->
      case File.read(path) do
        {:ok, bin} -> acc + length(String.split(bin, "\n"))
        _ -> acc
      end
    end)
  end

  defp count_domains do
    length(Application.get_env(:intellispark, :ash_domains, []))
  end
end
