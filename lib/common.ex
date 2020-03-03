defmodule Common do
  @moduledoc """
  The common structures and functions for communication within an emie-cluster.
  """

  require Logger

  @doc ~s"""
  `IO.inspect(something, label: "XX")` is so easy to use because it will return
  `something` unchanged, thus `IO.inspect` can be used in pipes. That's not the
  case with `Logger.level(param)` First, the parameter must be a string and other
  than that, `Logger.info/warn/error` returns `:ok` and not the object.
  So, this little helper wraps the object being logged and returns it, thus you
  can use it in pipes.

  ### Example:

      iex> object = {:a,:b,:c}
      ...> Common.log(object, :info, label: "My Object")
      {:a,:b,:c}

  """
  def log(object, level, options \\ []) do
    msg =
      case options[:label] do
        nil ->
          ""

        "" ->
          ""

        label ->
          "#{label}: "
      end <> inspect(object, options)

    case level do
      :debug -> Logger.debug(msg)
      :info -> Logger.info(msg)
      :warn -> Logger.warn(msg)
      :error -> Logger.error(msg)
      l -> Logger.warn("loglevel #{inspect(l)} is not known. Message: #{msg}")
    end

    object
  end
end
