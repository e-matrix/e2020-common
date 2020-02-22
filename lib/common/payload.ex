defmodule Common.Payload do
  @moduledoc """
  The structure to be used to wrap the payload of an e2020 request
  from one service to another.
  """

  require Logger

  @doc """
  The common payload for jwt-communication between services using this module is a
  simple struct of

      service_id ........... a unique id of the service sending a request eg e2020-frontend
      service_host ......... the host of the service sending the request eg abuntu.local
      logged_in_user_id .... the user_id of an eventually logged in user at the sender or nil
      resource_owner_id .... the owner_id of the resource mentioned in the request or nil
      claims ............... A simple map of params for the request
                             (what originally may come from a web form)

  """
  @derive {Jason.Encoder,
           only: [:service_id, :service_host, :logged_in_user_id, :resource_owner_id, :claims]}
  defstruct service_id: nil,
            service_host: nil,
            logged_in_user_id: nil,
            resource_owner_id: nil,
            claims: %{}

  @doc """
  Create a new `%Payload{}` structure from a map
  """
  def new(map) do
    %Common.Payload{
      service_id: map["service_id"],
      service_host: map["service_host"],
      logged_in_user_id: map["logged_in_user_id"],
      resource_owner_id: map["resource_owner_id"],
      claims: map["claims"] |> ensure_atom_keys()
    }
  end

  @doc """
  Build and sign a jwt-string with merged in `params`.
  """
  def build_signed_jwt_string(%{} = params, logged_in_user_id \\ nil, resource_owner_id \\ nil) do
    extra_claims =
      %Common.Payload{
        service_id: System.get_env("SERVICE_ID"),
        service_host: System.get_env("SERVICE_HOST"),
        logged_in_user_id: logged_in_user_id,
        resource_owner_id: resource_owner_id,
        claims: params
      }
      |> Common.log(:debug, label: "COMMON build_signed_jwt_string for payload")

    token = generate_and_sign(extra_claims)

    {token, extra_claims}
    |> Common.log(:debug, label: "build_signed_jwt_string returns")
  end

  def verify_and_validate(token) do
    signer =
      Joken.Signer.create(
        "HS256",
        System.get_env("JWT_SIGNER") || raise("JWT_SIGNER IS NOT DEFINED")
      )

    Common.JwtToken.verify_and_validate(token, signer)
    |> Common.log(:debug, label: "verified_and_validated")
  end

  defp generate_and_sign(extra_claims) do
    signer =
      Joken.Signer.create(
        "HS256",
        System.get_env("JWT_SIGNER") || raise("JWT_SIGNER IS NOT DEFINED")
      )

    Common.JwtToken.generate_and_sign!(extra_claims, signer)
    |> Common.log(:debug, label: "generated and signed with claims")
  end

  @doc """
  Unpack and validate a signed jwt-string and return it as an decrypted `%Payload{}` or
  `{:error, reason}` if validation fails.
  """
  def unpack_signed_jwt_string(jwt_string) when is_binary(jwt_string) do
    Logger.debug("COMMON unpack_signed_jwt_string of `#{jwt_string}`")

    jwt_string |> Base.decode64!() |> Jason.decode!() |> IO.inspect(label: "decoded")
  end

  def unpack_signed_jwt_string({:ok, response}) do
    {:ok, response}
  end

  def unpack_signed_jwt_string({:error, reason}) do
    {:error, reason}
  end

  def unpack_signed_jwt_string(request_model) do
    {:error,
     "request_model is not a valid. It should be an jwt-string or a response-tuple. " <>
       "Request was: `#{inspect(request_model)}"}
  end

  defp ensure_atom_keys(map) do
    for {key, val} <- map, into: %{} do
      cond do
        is_binary(key) -> {String.to_atom(key), val}
        true -> {key, val}
      end
    end
  end
end
