defmodule Otis.Library.Airplay.Shairport do
  @exe "shairport-sync"

  def installed? do
    case executable() do
      nil -> false
      _ -> true
    end
  end

  def executable do
    System.find_executable(@exe)
  end

  def version do
    cmd(["-V"]) |> parse_version()
  end

  def version_major, do: version() |> elem(0)

  def config_file do
    Path.join([:code.priv_dir(:otis_library_airplay), "conf/shairport-v#{version_major()}.conf"]) |> Path.expand()
  end

  def run(n) do
    ExternalProcess.spawn(executable(), args(n), [in: "", out: {:send, self()}, err: {:send, self()}])
  end

  def stop(process) do
    ExternalProcess.signal(process, 2)
    ExternalProcess.stop(process)
    ExternalProcess.await(process, :infinity)
  end

  def name(n) do
    "Strobe #{n}"
  end

  def port(n) do
    4999 + n
  end

  def args(n) do
    [ "--configfile=#{config_file()}",
      "--name=#{name(n)}",
      "--output=stdout",
      "--port=#{port(n)}",
    ]
  end

  def cmd(args) do
    case System.cmd(executable(), args) do
      {out, 0} ->
        {:ok, out}
      {error, _code} ->
        {:error, error}
    end
  end

  # for some reason -V gives an exit status of 1, output is along lines of:
  # "3.0.2-OpenSSL-ao-stdout-pipe-soxr-metadata-sysconfdir:/usr/local/etc/shairport-sync\n"
  defp parse_version({_status, version_output}) do
    version_output
    |> String.split("-")
    |> List.first
    |> String.split(".")
    |> List.to_tuple
  end
end
