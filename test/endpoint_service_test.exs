defmodule EndpointServiceTest do
  use ExUnit.Case
  doctest Common.EndpointService

  import Common.Comm, only: [call_service: 2]

  defmodule MyEndpointService do
    use Common.EndpointService, name: EndpointServiceTest.MyEndpointService

    @impl true
    def info() do
      %{name: "#{__MODULE__}"}
    end
  end

  @endpoint EndpointServiceTest.MyEndpointService

  describe "EndpointService Basics" do
    test "can start endpoint" do
      assert {:ok, pid} = @endpoint.start_link([])
      assert is_pid(pid)
    end
  end

  describe "Endpoint API" do
    setup [:start_endpoint]

    test ".info() returns meta data", %{pid: pid} do
      assert {:ok, %{name: "#{@endpoint}"}} == call_service(:info, pid)
    end

    test ".info() returns {:error, :node_down} if not reachable" do
      assert {:error, :node_down} == call_service(:info, UnknownOrDownEndpoint)
    end
  end

  defp start_endpoint(_) do
    with {:ok, pid} <- @endpoint.start_link([]) do
      {:ok, %{pid: pid}}
    else
      err ->
        IO.inspect(err, label: "Can't start endpoint")
        {:error, "Can't start endpoint #{inspect(err)}"}
    end
  end
end
