defmodule Strobe.Server.Fs do
  use     GenServer
  require Logger

  defmodule Mount do
    defstruct [:device, :mountpoint, :type]
  end

  def start_link(opts) do
    IO.inspect [:start_link, opts]
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    GenServer.cast(self(), :mount)
    {:ok, []}
  end

  def handle_info(:mount, state) do
    scan(state)
  end

  def handle_cast(:mount, state) do
    scan(state)
  end

  defp device, do: "/dev/sda1"
  defp mount_point, do: "/state"

  defp scan(state) do
    device() |> File.stat |> try_mount(state)
  end

  defp try_mount({:error, :enoent}, state) do
    # TODO: give up after 30s
    IO.inspect [__MODULE__, :wait, device()]
    Process.send_after(self(), :mount, 1_000)
    {:noreply, state}
  end
  defp try_mount({:ok, %File.Stat{type: :device} = stat}, state) do
    IO.inspect [__MODULE__, :mount, device(), stat]
    case mount(device(), mount_point()) do
      {_stdout, 0} ->
        Strobe.Server.Events.notify({:running, [:mount, device(), mount_point()]})
        {:stop, :normal, state}
      {stdout, err} ->
        Logger.error "Unable to mount #{device()} at #{mount_point()} got result #{err}: #{stdout}"
        {:stop, :error, state}
    end
  end
  defp try_mount(stat, state) do
    IO.inspect [__MODULE__, :error, device(), stat]
    Process.send_after(self(), :mount, 1_000)
    {:noreply, state}
  end

  defp mount(device, mount_point) do
    System.cmd("/bin/mount", mount_args(device, mount_point)) |> make_structure()
  end

  defp make_structure({_, 0} = status) do
    Enum.each(["fs", "db"], fn(m) ->
      [mount_point(), m, "current"] |> Path.join |> IO.inspect |> File.mkdir_p()
    end)
    status
  end
  defp make_structure(status) do
    Logger.warn "Not building directory structure as FS not mounted"
    status
  end

  defp mount_args(device, mount_point) do
    [ "-t",
      "ext4",
      "-o",
      # https://www.kernel.org/doc/Documentation/filesystems/ext4.txt
      # Be slow but careful -- we want to avoid data corruption at all costs
      "noatime,noexec,nosuid,data=ordered,barrier=1",
      device,
      mount_point,
    ]
  end
end
