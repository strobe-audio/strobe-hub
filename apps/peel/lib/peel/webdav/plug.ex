defmodule Peel.WebDAV.Plug do
  defmacro __using__(_opts) do
    config = Application.get_env(:peel, Peel.Collection)
    quote do
      use Plug.Builder

      plug Peel.WebDAV.Classifier, unquote(config)
      plug Plug.WebDAV.Handler, unquote(config)
      plug Peel.WebDAV.Events, unquote(config)
    end
  end
end
