defmodule CommonTest do
  use ExUnit.Case
  doctest Common

  import Common.Comm, only: [call_service: 2, call_service: 3]

  defmodule PeopleServiceMock do
    use GenServer

    def start_link(_) do
      GenServer.start_link(PeopleServiceMock, %{}, name: PeopleServiceMock)
    end

    def init(state) do
      {:ok, state}
    end

    def handle_call(%{pay: load}, _from, state) do
      {:reply, {:ok, String.upcase(load)}, state}
    end
  end

  describe "Mocking a service" do
    setup [:start_service_mock]

    test "call_service(payload,service,emie_key)", %{service: service} do
      assert {:ok, "LOAD"} == call_service(%{pay: "load"}, service)
    end

    defp start_service_mock(_) do
      {:ok, pid} = PeopleServiceMock.start_link(%{})
      {:ok, %{service: pid}}
    end
  end

  @tag :integration
  describe "Firewall-tests for Inegrated Services" do
    test "Endpoints" do
      _endpoints_to_test =
        [
          {People.ServiceEndpoint, :info, {:ok, %{name: "People-Service"}}},
          {People.ServiceEndpoint, {:full_name, "bob"}, {:ok, "Robert C. Martin"}}
        ]
        |> Enum.each(fn {service, payload, expected} ->
          assert expected == call_service(payload, service)
        end)
    end
  end
end
