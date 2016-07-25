defmodule BBC do
  use     Application
  require Logger
  alias   BBC.Channel

  @library_id "bbc"

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(HLS.Supervisor, [], []),
      worker(BBC.Events, []),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  @channels [
    %Channel{id: "asian_network", title: "BBC Asian Network"},
    %Channel{id: "radio1", title: "BBC Radio 1"},
    %Channel{id: "radio1xtra", title: "BBC Radio 1Xtra"},
    %Channel{id: "radio2", title: "BBC Radio 2"},
    %Channel{id: "radio3", title: "BBC Radio 3"},
    %Channel{id: "radio4", title: "BBC Radio 4"},
    %Channel{id: "radio4extra", title: "BBC Radio 4 Extra"},
    %Channel{id: "radio4lw", title: "BBC Radio 4LW"},
    %Channel{id: "radio5live", title: "BBC Radio 5 Live"},
    %Channel{id: "radio5liveextra", title: "BBC Radio 5 Live Sports Extra"},
    %Channel{id: "radio6", title: "BBC Radio 6 Music"},
  ]
  @channel_names Enum.map(@channels, fn(%Channel{id: id}) -> id end)

  Enum.each @channels, fn(%Channel{id: id} = _channel) ->
    def unquote(String.to_atom(id))() do
      Enum.find(@channels, fn(%Channel{id: cid}) ->
        cid == unquote(id)
      end)
    end
  end

  def channels, do: @channels

  def find!(id) when id in @channel_names do
    find(id, id)
  end
  def find!(%Channel{id: id} = channel) do
    find(id, channel)
  end

  defp find(id, key) do
    @channels
    |> Enum.find(fn(%Channel{id: cid}) -> cid == id end)
    |> _validate_find!(key)
  end

  defp _validate_find!(nil, key), do: raise "BBC channel #{inspect key} not found"
  defp _validate_find!(result, _key), do: result

  def playlist(%Channel{id: id}) when id in @channel_names do
    path = Path.join([__DIR__, "bbc/channels/#{id}.m3u8"]) |> Path.expand
    file = File.read!(path)
    M3.Parser.parse!(file, "http://www.bbc.co.uk")
  end

  def playlist(channel) do
    raise "Unknown channel #{inspect channel}"
  end

  def library_id, do: "bbc"
end
