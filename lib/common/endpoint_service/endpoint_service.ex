defmodule Common.EndpointService do
  @moduledoc """
  A behaviour module you can use to implement your own `EndpointService`.

  ## Example

      defmodule MyServiceEndpoint do
        use Common.EndpointService, name: MyServiceEndpoint

        @impl true
        def info(), do: {:ok, %{ name: "My fancy service" }}

        def handle_call(:action, _from, state) do
          {:reply, {:ok, "Äction!"}, state}
        end
      end

      ..somewhere..
      call_service(:action, MyServiceEndpoint)
      #=> {:ok, "Äction!"}
  """

  @doc """
  Implement a function that returns the meta-information for your endpoint.

  ### Example

      def info, do: %{ name: "My Service Name", version: "x" }

  """
  @callback info() :: Map.t()

  @doc """
  Implement handle-functions for your implementation.
  """
  @callback handle(Map.t(), pid() | tuple(), any()) :: {:ok, any()} | {:error, String.t()}

  defmacro __using__(opts) do
    quote do
      @moduledoc """
      Endpoint Implementation for `#{unquote(opts[:name])}`


      ### API Implementations Added by `__using__`

          info()
          handle_call(:info, _, _)
          handle_call({token, %Payload{claims: ....}},_,_)

      """

      use GenServer
      @behaviour Common.EndpointService

      alias Common.Payload

      @doc """
      Start the endoint service. Returns `{:ok, pid}`
      """
      def start_link(_) do
        name = unquote(opts[:name])

        GenServer.start_link(__MODULE__, %{}, name: name)
      end

      @doc "Default init sets empty state `%{}`"
      @impl true
      def init(_), do: {:ok, %{}}

      @doc "call `:info` does nothing than calls your implementation of `info/1`"
      @impl true
      def handle(%{"action" => "info"}, _from, state) do
        {:reply, {:ok, info()}, state}
      end

      @doc """
      Handle JWT call of form `{token, %Payload{}}`, extracts the claims and forwards
      to your implementation of `handle_call(claims, from, state)`
      """
      @impl true
      def handle_call({token, %Payload{claims: predicted_claims}}, from, state)
          when is_binary(token) do
        token
        |> Payload.verify_and_validate()
        |> Common.log(:debug, label: "Validated")
        |> case do
          {:ok, %{"claims" => claims}} ->
            Common.log({predicted_claims, claims}, :debug, label: "{predicted, verified}")
            unquote(opts[:name]).handle(claims, from, state)

          {:error, reason} ->
            Common.log(reason, :error, label: "Can't verify token")
            {:reply, {:error, "JWT verify failed with #{inspect(reason)}"}, state}
        end
      end

      @impl true
      def handle_call(msg, from, state), do: handle(msg, from, state)
    end
  end
end
