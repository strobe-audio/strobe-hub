defmodule ExternalProcess.Driver do
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    ## TODO: re-enable this when we have a working ARM goon driver
    Logger.info("Configuring porcelain with Goon driver at #{ExternalProcess.goon_driver_path()}")
    Application.put_env(:porcelain, :driver, Porcelain.Driver.Goon)
    Application.put_env(:porcelain, :goon_driver_path, ExternalProcess.goon_driver_path())
    Porcelain.reinit()

    :ignore
  end
end
