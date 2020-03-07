defmodule Common.Comm do
  @moduledoc """
  Common Communication Module for e2020


  `call_service(....)`
  """

  alias Common.Payload

  @doc """
  Call a GenServer in a remote application or locally if the worker is a pid.

  There are two types matching this function. The first one is for a single query or
  command with no parameters. Other than that, there is a form where the first param
  is a tuple of `{ :action_key, %{ ..params.. }}`.

  **Form 1 - query, command with no params**

      call_service(:something_the_service_knows, ServiceEndpoint, emie_key)

  **Form 2 - query, command with params**

      call_service({:something_the_service_knows, %{ "p1" => "v1", ....}}, ServiceEndpoint, emie_key)

  The _ServiceEndpoint_ can either be

    - a module where the service endpoint is defined
    - a pid where the endpoint's GenServer is running

  ### Examples

      iex> call_service(:info, People.ServiceEndpoint, "mycurrentusername")

      iex> call_service({:full_name, %{ "username" => "bob" }}, People.ServiceEndpoint, "mycurrentusername")

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
    String.upcase("#{service_name}")
    |> String.split(".")
    |> case do
      [oneword] when is_binary(oneword) ->
        "EMIE_2020_#{oneword}_SERVICE"

      ["ELIXIR", srv_name | _] ->
        "EMIE_2020_#{srv_name}_SERVICE"
    end
    |> System.get_env()
    |> or_default("service_not_defined@local")
    |> String.to_atom()
    |> IO.inspect(label: "Using FQSN")
  end

  defp or_default(nil, default), do: default
  defp or_default(value, _), do: value

  defp cast_payload({key, %{} = params} = payload, _service_endpoint, emie_key)
       when is_tuple(payload) do
    %{
      "action" => "#{key}",
      "params" => Map.merge(params, %{"emie_key" => emie_key})
    }
  end

  defp cast_payload(action, _service_endpoint, _emie_key) when is_atom(action) do
    %{"action" => "#{action}"}
  end

  defp cast_payload(payload, _service_endpoint, _emie_key),
    do: raise("Invalid payload #{inspect(payload)}")

  defp safe_call_service(signed_jwt_string, service_endpoint) do
    signed_jwt_string
    |> case do
      {:error, _reason} = err ->
        Common.log(err, :debug, label: "Can't sign payload")

      payload ->
        Common.log(payload, :debug, label: "Signed payload")

        GenServer.call(
          {service_endpoint, full_qualified_service_node(service_endpoint)},
          payload
        )
        |> Common.log(:debug, label: "#{inspect(service_endpoint)} responds")
    end
  end
end
