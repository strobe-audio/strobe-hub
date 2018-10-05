defmodule Otis.Library.Airplay.Input.Metadata do
  def start_link(n, input_pid) do
    GenServer.start_link(__MODULE__, {n, input_pid})
  end

  def init({n, input_pid}) do
    Process.send_after(self(), :connect, 1_000)
    {:ok, %{n: n, input: input_pid, fifo: nil}}
  end

  def handle_info(:connect, state) do
    %{n: n} = state
    fifo =
      "/tmp/shairport-metadata-pipe-#{n}"
      |> to_charlist()
      |> :erlang.open_port([:eof])
    {:noreply, %{state | fifo: fifo}}
  end

  @no_event %{type: nil, code: nil}

  def handle_info({fifo, {:data, xml}}, %{fifo: fifo} = state) do
    # IO.inspect [:data, xml]
    xml
    |> to_charlist()
    |> :xmerl_sax_parser.stream(
      event_fun: fn
      {:ignorableWhitespace, _}, _, sax_state ->
        sax_state
      {:startElement, _uri, 'type', _, _attr}, _, sax_state ->
        %{sax_state | tag: :type}
      {:startElement, _uri, 'code', _, _attr}, _, sax_state ->
        %{sax_state | tag: :code}
      {:startElement, _uri, 'data', _, _attr}, _, sax_state ->
        %{sax_state | tag: :data}
      {:characters, chars}, _, %{buffer: buffer} = sax_state ->
        data = IO.chardata_to_string(chars)
      %{sax_state | buffer: [buffer, data]}
    {:endElement, _uri, _tag, _}, _, %{tag: :data} = sax_state ->
        %{buffer: buffer} = sax_state
      data =
        buffer
        |> IO.iodata_to_binary()
        |> Base.decode64!()
      # IO.inspect [:XX, :data, data]
      %{sax_state | tag: nil, buffer: []}
    {:endElement, _uri, _tag, _}, _, %{tag: tag} = sax_state when tag in [:type, :code] ->
        %{buffer: buffer} = sax_state
      data =
        buffer
        |> IO.iodata_to_binary()
        |> Base.decode16!(case: :lower)
      # IO.inspect [:XX, tag, data]
      handle_event(%{sax_state | tag: nil, buffer: [], event: %{sax_state.event | tag => data}}, state)
      event, location, sax_state ->
        # IO.inspect [event, sax_state]
        sax_state
    end,
    continuation_fun: fn sax_state ->
      IO.inspect [:continuation_fun]
      receive do
        {fifo, {:data, xml}} ->
          {to_charlist(xml), sax_state}
      end
    end,
    event_state: %{tag: nil, buffer: [], event: @no_event}
    )
    {:noreply, state}
  end

  def handle_event(%{event: %{type: "ssnc", code: "flsr"}} = sax_state, state) do
    IO.inspect [:airplay, "flsr", :flush]
    send(state.input, {:airplay, :flush})
    %{sax_state | event: @no_event}
  end

  def handle_event(%{event: %{type: "ssnc", code: "pbeg"}} = sax_state, state) do
    IO.inspect [:airplay, "pbeg", :start]
    send(state.input, {:airplay, :start})
    %{sax_state | event: @no_event}
  end

  def handle_event(%{event: %{type: "ssnc", code: "pfls"}} = sax_state, state) do
    IO.inspect [:airplay, "pfls", :stop]
    send(state.input, {:airplay, :stop})
    %{sax_state | event: @no_event}
  end

  def handle_event(%{event: %{type: "ssnc", code: "prsm"}} = sax_state, state) do
    IO.inspect [:airplay, "prsm", :start]
    send(state.input, {:airplay, :start})
    %{sax_state | event: @no_event}
  end

  def handle_event(%{event: %{type: "ssnc", code: "pend"}} = sax_state, state) do
    IO.inspect [:airplay, "pend", :stop]
    send(state.input, {:airplay, :stop})
    %{sax_state | event: @no_event}
  end

  def handle_event(%{event: %{type: type, code: code}} = sax_state, _state)
  when not is_nil(type) and not is_nil(code) do
    IO.inspect [:event, type, code]
    %{sax_state | event: @no_event}
  end

  def handle_event(sax_state, _state) do
    sax_state
  end
end
