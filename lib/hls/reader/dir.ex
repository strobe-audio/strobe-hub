defmodule HLS.Reader.Dir do
  defstruct [:root]

  alias __MODULE__

  def new(root) do
    %Dir{root: root}
  end

  def path(url) do
    %URI{path: path} = URI.parse(url)
    path
  end
end

defimpl HLS.Reader, for: HLS.Reader.Dir do
  def read!(reader, "http" <> _ = url) do
    path = HLS.Reader.Dir.path(url)
    file_path = Path.join([reader.root, path])
    File.read!(file_path)
  end

  def read!(reader, path) do
    file_path = Path.join([reader.root, path])
    File.read!(file_path)
  end
end
