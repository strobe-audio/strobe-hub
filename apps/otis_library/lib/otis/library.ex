defmodule Otis.Library do
  def strip_leading_dot(ext) do
    String.lstrip(ext, ?.)
  end

  defmacro __using__([namespace: namespace]) do
    quote location: :keep do
      @namespace "#{unquote(namespace)}"
      @protocol "#{unquote(namespace)}:"

      def start_link do
        GenStage.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init(_opts) do
        {:consumer, [], subscribe_to: Otis.Library.Events.producer}
      end

      def handle_events([], _from, state) do
        {:noreply, [], state}
      end
      def handle_events([event|events], from, state) do
        {:ok, state} = handle_event(event, state)
        handle_events(events, from, state)
      end

      def handle_event({:otis_started, _args}, state) do
        {:ok, setup(state)}
      end

      def handle_event({:controller_join, [socket]}, state) do
        notify_event({:add_library, [library(), socket]})
        {:ok, state}
      end

      def handle_event({:library_request, [channel_id, (@protocol <> path) = url, socket, query]}, state) do
        response = handle_request(channel_id, path, query)
        notify_event({:library_response, [@namespace, url, response, socket]})
        {:ok, state}
      end

      def handle_event(_event, state) do
        {:ok, state}
      end

      if Code.ensure_compiled?(Otis.Events) do
        def notify_event(event) do
          Otis.Events.notify(event)
        end
      else
        def notify_event(event) do
        end
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
        route_library_request(channel_id, split(path), query, path)
      end

      def route_library_request(_channel_id, _route, _query, _path) do
        nil
      end

      def library_link(title, action \\ nil)
      def library_link(title, action) do
        %{title: title, action: action}
      end

      def url(path) when is_list(path) do
        path |> Enum.map(&encode/1) |> Path.join |> url()
      end

      def url(path) do
        "#{@protocol}#{path}"
      end

      def split(path) do
        path |> Path.split |> Enum.map(&decode/1)
      end

      defp encode(part), do: URI.encode(part, &URI.char_unreserved?/1)
      defp decode(part), do: URI.decode(part)

      if Code.ensure_compiled?(Otis.Channel) do
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
      else
        def play(_source, _channel_id), do: nil
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

