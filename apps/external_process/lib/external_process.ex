defmodule ExternalProcess do
  @moduledoc """
  Provides a wrapper around Porcelain that takes care of providing the
  required Goon binaries
  """

  def spawn(prog, args, options \\ []) do
    Porcelain.reinit(Porcelain.Driver.Goon)
    Porcelain.spawn(prog, args, options)
  end

  def stop(process) do
    Porcelain.Process.stop(process)
  end

  def signal(process, signal) do
    Porcelain.Process.signal(process, signal)
  end

  def await(process, timeout \\ :infinity) do
    Porcelain.Process.await(process, timeout)
  end
end
