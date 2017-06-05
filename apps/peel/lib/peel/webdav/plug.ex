defmodule Peel.Webdav.Plug do
  defmacro __using__(_opts) do
    config = Application.get_env(:peel, Peel.Collection)
    quote do
      use Plug.Builder

      plug Peel.Webdav.Classifier, unquote(config)
      plug Plug.WebDav.Handler, unquote(config)
      plug Peel.Webdav.Events, unquote(config)
    end
  end
end
