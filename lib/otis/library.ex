defmodule Otis.Library do
  defmacro __using__([namespace: namespace]) do
    quote location: :keep do
      @namespace "#{unquote(namespace)}"
      @protocol "#{unquote(namespace)}:"

      def handle_event({:controller_join, socket}, state) do
        Otis.State.Events.notify({:add_library, library(), socket})
        {:ok, state}
      end

      def handle_event({:library_request, channel_id, @protocol <> path, socket}, state) do
        route = String.split(path, "/", trim: true)
        case route_library_request(channel_id, route, path) do
          nil ->
            nil
          response ->
            Otis.State.Events.notify({:library_response, @namespace, response, socket})
        end
        {:ok, state}
      end

      def handle_event(_event, state) do
        {:ok, state}
      end

      def init do
      end

      def library do
        %{ id: "invalid",
          title: "Override me",
          icon: "",
          actions: %{
            click: url("root"),
            play: nil
          },
          metadata: nil
        }
      end

      def route_library_request(_channel_id, _route, _path) do
        nil
      end

      def library_link(title, action \\ nil)
      def library_link(title, action) do
        %{title: title, action: action}
      end

      def url(path) when is_list(path) do
        path |> Path.join |> url()
      end

      def url(path) do
        "#{@protocol}#{path}"
      end


      def play(nil, _channel_id) do
        nil
      end
      def play(tracks, channel_id) when is_list(tracks) do
        with {:ok, channel} <- Otis.Channels.find(channel_id) do
          Otis.Channel.append(channel, tracks)
        end
        nil
      end
      def play(track, channel_id) do
        play([track], channel_id)
      end


      def namespace, do: @namespace

      defoverridable [
        init: 0,
        library: 0,
        route_library_request: 3,
      ]
    end
  end
end

