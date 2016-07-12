defmodule HLS do
  def start(_type, _args) do
    HLS.Supervisor.start_link([])
  end
end
