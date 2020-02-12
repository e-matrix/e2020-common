defmodule Common do
  @moduledoc """
  The common structures and function for communication within an emie-cluster.


  `Common.Payload` ... a module to deal with payloads between e2020 services.
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
    case level do
      :info -> Logger.info(inspect(object, options))
      :warn -> Logger.warn(inspect(object, options))
      :error -> Logger.error(inspect(object, options))
      l -> Logger.warn("loglevel #{inspect(l)} is not known. Object: #{inspect(object, options)}")
    end

    object
  end
end
