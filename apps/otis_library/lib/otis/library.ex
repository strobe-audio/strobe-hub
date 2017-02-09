defmodule Otis.Library do
  defmacro __using__([namespace: namespace]) do
    quote location: :keep do
      @namespace "#{unquote(namespace)}"
      @protocol "#{unquote(namespace)}:"

      def handle_event({:otis_started, _args}, state) do
        {:ok, setup(state)}
      end

      def handle_event({:controller_join, [socket]}, state) do
        Otis.State.Events.notify({:add_library, [library(), socket]})
        {:ok, state}
      end

      def handle_event({:library_request, [channel_id, (@protocol <> path) = url, socket, query]}, state) do
        response = handle_request(channel_id, path, query)
        Otis.State.Events.notify({:library_response, [@namespace, url, response, socket]})
        {:ok, state}
      end

      def handle_event(_event, state) do
        {:ok, state}
      end

      def setup(state) do
        state
      end

      def library do
        %{ id: "invalid",
          title: "Override me",
          icon: "",
          actions: %{
            click: %{ url: url("root"), level: true },
            play: nil,
            search: nil,
          },
          metadata: nil
        }
      end

      def handle_request(channel_id, path, query \\ nil)
      def handle_request(channel_id, path, query) do
        route = String.split(path, "/", trim: true)
        route_library_request(channel_id, route, query, path)
      end

      def route_library_request(_channel_id, _route, _query, _path) do
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

      def namespaced(url), do: "#{@namespace}:#{url}"

      @section_defaults %{ title: "", actions: nil, metadata: nil, icon: nil, size: "s", children: [] }

      def section(%{children: children} = section_data) do
        @section_defaults |> Map.merge(section_data) |> Map.merge(%{ length: length(children) })
      end

      defoverridable [
        setup: 1,
        library: 0,
        route_library_request: 4,
      ]
    end
  end
end

