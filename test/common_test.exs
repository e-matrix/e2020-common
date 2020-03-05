defmodule CommonTest do
  use ExUnit.Case
  doctest Common

  import Common.Comm, only: [call_service: 2, call_service: 3]
  import ExUnit.CaptureIO

  alias Common.Comm

  defmodule ServiceMock do
    use GenServer

    def start_link(_) do
      GenServer.start_link(ServiceMock, %{}, name: ServiceMock)
    end

    def init(state) do
      {:ok, state}
    end

    def handle_call(%{pay: load}, _from, state) do
      {:reply, {:ok, String.upcase(load)}, state}
    end

    def handle_call(pl, _from, state) do
      IO.inspect(pl, label: "MOCK HANDLES")
      {:reply, {:error, "Unknown payload"}, state}
    end
  end

  describe "Mocking a service" do
    setup [:start_service_mock]

    test "call_service(payload,service)", %{service: service} do
      assert {:ok, "LOAD"} == call_service(%{pay: "load"}, service)
    end

    test "call_service(payload,service,emie_key)", %{service: service} do
      assert {:ok, "LOAD"} == call_service(%{pay: "load"}, service, "emie-key")
    end

    defp start_service_mock(_) do
      {:ok, pid} = ServiceMock.start_link(%{})
      {:ok, %{service: pid}}
    end
  end

  describe "Common Communication Helpers" do
    test "full_qualified_service_node" do
      System.put_env("EMIE_2020_HELO_SERVICE", "helo@local")

      assert :helo@local == Comm.full_qualified_service_node(Elixir.Helo.ServiceEndpoint)

      System.delete_env("EMIE_2020_HELO_SERVICE")
    end
  end

  describe "Global functions" do
    test "output logs if EMIE_2020_LOG_ON is set" do
      old = System.get_env("EMIE_2020_LOG_ON")

      # When the env var is set
      System.put_env("EMIE_2020_LOG_ON", "yes")

      # And we use our log-function
      output =
        capture_io(fn ->
          Common.log("Something", :debug)
        end)

      # Then we should see an output
      assert "\nLOG-debug : \"Something\"\n" == output

      # Reset environment
      System.delete_env("EMIE_2020_LOG_ON")

      if old do
        System.put_env("EMIE_2020_LOG_ON", old)
      end
    end

    test "don't output logs if EMIE_2020_LOG_ON isn't set" do
      old = System.get_env("EMIE_2020_LOG_ON")

      # When the env var is not set (nil)
      System.delete_env("EMIE_2020_LOG_ON")

      # And we use our log function
      output =
        capture_io(fn ->
          Common.log("Something", :debug)
        end)

      # Then we shouldn't see any output
      assert "" == output

      # Reset environment if it was set before
      if old do
        System.put_env("EMIE_2020_LOG_ON", old)
      end
    end
  end

  @tag :integration
  describe "Firewall-tests for Inegrated Services" do
    test "Endpoints" do
      _endpoints_to_test =
        [
          {Authentication.ServiceEndpoint, :info,
           {:ok, {:ok, %{name: "Authentication-Service"}}}},
          {People.ServiceEndpoint, :info, {:ok, {:ok, %{name: "People-Service"}}}},
          {People.ServiceEndpoint, {:full_name, %{username: "bob"}},
           {:ok, {:ok, "Robert C. Martin"}}}
        ]
        |> Enum.each(fn {service, payload, expected} ->
          assert expected == call_service(payload, service)
        end)
    end
  end
end
