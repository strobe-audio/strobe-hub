defmodule Strobe.Server.Fs do
  use     GenServer
  require Logger

  defmodule Mount do
    defstruct [:device, :mountpoint, :type]
  end

  def start_link(opts) do
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
    device() |> File.stat |> test_fs(state) |> try_mount(state)
  end

  defp test_fs({:error, :enoent} = err, _state) do
    err
  end
  defp test_fs({:ok, %File.Stat{type: :device} = stat}, _state) do
    case partition_type(device()) do
      {:ok, %{"TYPE" => type}} ->
        IO.inspect [:type, type]
        case reformat(type, device()) do
          :ok -> {:ok, stat}
          err -> err
        end
      {:ok, info} ->
        IO.inspect [:WEIRD, info]
        {:err, "Unable to determine partition type: #{inspect info}"}
      err -> IO.inspect err
    end
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
    [mount_point(), "tmp"] |> Path.join |> IO.inspect |> File.mkdir_p
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

  defp partition_type(device) do
    case probe_type(device) do
      {result, 0} ->
        {:ok, parse_blkid_response(result)}
      {err, _n} ->
        {:error, err}
    end
  end

  @doc ~S"""
  Parses the result of blkid <device> and returns a hash of the info.

      iex> Strobe.Server.Fs.parse_blkid_response(~s{/dev/sdb1: LABEL="BOO" UUID="83A2-1C0E" TYPE="vfat"\n})
      %{"LABEL" => "BOO", "UUID" => "83A2-1C0E", "TYPE" => "vfat" }

      iex> Strobe.Server.Fs.parse_blkid_response(~s{/dev/sdb1: LABEL="BOO HOO" UUID="83A2-1C0E" TYPE="vfat"\n})
      %{"LABEL" => "BOO HOO", "UUID" => "83A2-1C0E", "TYPE" => "vfat" }

  """
  def parse_blkid_response(response) do
    [_dev, info] = response |> String.trim |> String.split(":")
    matches = Regex.scan(~r{([A-Z]+)="([^"]+)"}, info)
    matches |> Enum.map(fn([_, k, v]) -> {k, v} end) |> Enum.into(%{})
  end
  defp probe_type(device) do
    System.cmd(blkid(), [device])
  end

  defp blkid do
    System.find_executable("blkid")
  end

  defp reformat("ext4", _device), do: :ok
  defp reformat(type, device) do
    IO.inspect [:reformatting, device, type]
    case mkfs(device) do
      {_, 0} -> :ok
      {err, _} -> {:error, err}
    end
  end

  defp mkfs(device) do
    "mkfs.ext4" |> System.find_executable |> System.cmd([device])
  end
end
