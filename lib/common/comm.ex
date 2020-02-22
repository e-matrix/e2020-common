defmodule Common.Comm do
  @moduledoc """
  Common Communication Module for e2020
  """

  alias Common.Payload

  @doc """
  Call a GenServer in a remote application
  """
  def call_service(payload, service_endpoint, emie_key \\ nil)

  def call_service(payload, People.ServiceEndpoint = service_endpoint, emie_key) do
    case Node.ping(people_service(service_endpoint)) do
      :pong ->
        cond do
          is_atom(payload) ->
            %{"action" => "#{payload}"}

          is_tuple(payload) ->
            %{
              "action" => "#{elem(payload, 0)}",
              "params" => %{"username" => elem(payload, 1), "emie_key" => emie_key}
            }

          true ->
            raise "Invalid payload #{inspect(payload)}"
        end
        |> Payload.build_signed_jwt_string()
        |> case do
          {:error, reason} ->
            Common.log(:error, reason, label: "Can't sign payload")

          payload ->
            Common.log(payload, :debug, label: "Signed payload")

            GenServer.call(
              {service_endpoint, people_service(service_endpoint)},
              payload
            )
            |> Payload.unpack_signed_jwt_string()
            |> Common.log(:debug, label: "Verified jwt-string (#{service_endpoint})")
        end

      :pang ->
        {:error, :node_down}
        |> Common.log(:debug, label: "Node #{inspect(service_endpoint)}")
    end
  end

  def call_service(payload, local_worker, _emie_key) do
    case GenServer.whereis(local_worker) do
      nil ->
        {:error, :node_down}
        |> Common.log(:debug, label: "Service called: #{inspect(local_worker)}")

      pid ->
        GenServer.call(pid, payload)
        |> Payload.unpack_signed_jwt_string()
        |> Common.log(:debug, label: "Verified jwt-string (local_worker)")
    end
  end

  defp people_service(People.ServiceEndpoint) do
    (System.get_env("EMIE_2020_PEOPLE_SERVICE") ||
       raise("EMIE_2020_PEOPLE_SERVICE not configured"))
    |> String.to_atom()
    |> Common.log(:debug, label: "Using people-service at")
  end

  defp people_service(local), do: local
end
