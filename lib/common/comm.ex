defmodule Common.Comm do
  @moduledoc """
  Common Communication Module for e2020


  `call_service(....)`
  """

  alias Common.Payload

  @doc """
  Call a GenServer in a remote application or locally if the worker is a pid.

  """
  @spec call_service(map() | tuple() | :atom, :atom | pid(), String.t()) ::
          {:ok, term} | {:error, String.t()}
  def call_service(payload, service_endpoint, emie_key \\ nil)

  def call_service(payload, local_worker, _emie_key) when is_pid(local_worker) do
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

  def call_service(payload, service_endpoint, emie_key) do
    case Node.ping(full_qualified_service_node(service_endpoint)) do
      :pong ->
        cast_payload(payload, service_endpoint, emie_key)
        |> Payload.build_signed_jwt_string()
        |> safe_call_service(service_endpoint)

      :pang ->
        {:error, :node_down}
        |> Common.log(:debug, label: "Node #{inspect(service_endpoint)}")
    end
  end

  @doc """
  Return the service endpoint address for the given `service_name`.
  There must be a system env, named `EMIE_2020_servicename_SERVICE`.
  If this env exists, it will be returned as an atom. Otherwise an
  exception will raise.

  ### Example

      iex> full_qualified_service_node(Elixir.MyService.ServiceEndpoint)
      :"my_service@node.local"

  """
  def full_qualified_service_node(service_name) do
    ["ELIXIR", srv_name | _] = String.upcase("#{service_name}") |> String.split(".")

    "EMIE_2020_#{srv_name}_SERVICE"
    |> System.get_env()
    |> String.to_atom()
  end

  defp cast_payload(action, _service_endpoint, _emie_key) when is_atom(action) do
    %{"action" => "#{action}"}
  end

  defp cast_payload({key, %{} = params} = payload, service_endpoint, emie_key)
       when is_tuple(payload) do
    %{
      "action" => "#{key}",
      "params" => Map.merge(params, %{"emie_key" => emie_key})
    }
  end

  defp cast_payload(payload, service_endpoint, emie_key),
    do: raise("Invalid payload #{inspect(payload)}")

  defp safe_call_service(signed_jwt_string, service_endpoint) do
    signed_jwt_string
    |> case do
      {:error, reason} ->
        Common.log(:error, reason, label: "Can't sign payload")

      payload ->
        Common.log(payload, :debug, label: "Signed payload")

        GenServer.call(
          {service_endpoint, full_qualified_service_node(service_endpoint)},
          payload
        )
        |> Payload.unpack_signed_jwt_string()
        |> Common.log(:debug, label: "Verified jwt-string (#{service_endpoint})")
    end
  end
end
