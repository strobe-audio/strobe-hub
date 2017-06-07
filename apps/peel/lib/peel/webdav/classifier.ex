defmodule Peel.WebDAV.Classifier do
  import Plug.Conn, only: [assign: 3]
  def init(opts) do
    case Keyword.pop(opts, :root) do
      {nil, _opts} ->
        raise ArgumentError, "#{__MODULE__} options must include a :root key"
      {root, opts} ->
        {Path.expand(root), opts}
    end
  end

  def call(conn, {root, _} = _opts) do
    {type, _path} = path_type(conn, root)
    conn |> assign(:type, type)
  end

  def path_type(%Plug.Conn{path_info: []}, _root) do
    {:root, "/"}
  end
  def path_type(%Plug.Conn{path_info: path_info}, root) do
    path = decode(path_info)
    abs = [root | path] |> Path.join
    rel = ["/" | path] |> Path.join
    path_type(abs, rel)
  end
  def path_type(abs_path, rel_path) do
    type =
      cond do
        # Test for hidden first because we just want to skip them based on
        # their abs_path, irrespective of their actual file status
        is_hidden?(abs_path) ->
          :hidden
        !File.exists?(abs_path) ->
          :new
        File.regular?(abs_path) ->
          :file
        File.dir?(abs_path) ->
          :directory
        true ->
          :special
      end
    {type, rel_path}
  end

  defp is_hidden?(path) do
    case Path.basename(path) do
      <<".", _::binary>> ->
        true
      _ ->
        false
    end
  end

  defp decode(path_info), do: Enum.map(path_info, &URI.decode/1)
end
