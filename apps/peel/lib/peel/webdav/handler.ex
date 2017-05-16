defmodule Peel.Webdav.Handler do
  @moduledoc """
  A pass-through middleware that watches requests to the webdav server and
  produces events when any modification is made.
  """

  require Record
  import  Record, only: [defrecord: 2, extract: 2]

  defrecord :arg, extract(:arg, from_lib: "yaws/include/yaws_api.hrl")
  defrecord :http_request, extract(:http_request, from_lib: "yaws/include/yaws_api.hrl")
  defrecord :headers, extract(:headers, from_lib: "yaws/include/yaws_api.hrl")

  def out(arg(req: http_request(method: method)) = arg) do
    # Check the type before performing the operation or the thing we're
    # checking may disappear before we get to it...
    type = path_type(arg)
    resp = :yaws_appmod_dav.out(arg)
    method |> normalize_method |> handle_request(type, arg)
    resp
  end

  @ignored_methods [
    :OPTIONS,
    :HEAD,
    :GET,
    :LOCK,
    :UNLOCK,
    :PROPFIND,
    :MKCOL, # we're not interested in new directories...
  ]

  for m <- @ignored_methods do
    def handle_request(unquote(m), _type, _arg), do: nil
  end

  # Ignore anything that doesn't have pathinfo set
  def handle_request(_method, _type, arg(pathinfo: :undefined)), do: nil

  # The webdav clients recurse into the directory tree and send delete events
  # for every contained file and directory so I don't need to worry about
  # DELETE events of type :directory.
  def handle_request(:DELETE, {:file, path}, _arg) do
    emit_event({:delete, [path]})
  end
  def handle_request(:DELETE, _type, _arg), do: nil

  def handle_request(:MOVE, {kind, _path} = type, arg(headers: headers(other: other)) = arg)
  when kind in [:file, :directory] do
    :lists.keysearch('Destination', 3, other) |> move_request(type, arg)
  end
  def handle_request(:MOVE, _type, _arg) do
  end

  def handle_request(:PUT, {:file, path}, arg(clidata: clidata)) do
    case clidata do
      {:partial, _data} ->
        nil
      data when is_binary(data) ->
        # Only emit the event when the upload is complete
        emit_event({:create, [path]})
    end
  end
  def handle_request(_method, _type, _arg) do
    # Ignore everything else
  end

  def move_request({:value, {:http_header, _, 'Destination', _, uri}}, {type, src_path}, arg(docroot: docroot)) do
    destination = uri |> to_string |> URI.parse |> Map.get(:path) |> URI.decode
    dest_path = [to_string(docroot), destination] |> Path.join
    emit_event({:move, [type, src_path, dest_path]})
  end

  # Failed to find a Destination header in the request.. bascially a malformed
  # MOVE request
  def move_request(_, _type, _args) do
  end

  def emit_event(event) do
    Peel.Webdav.Modifications.notify(event)
  end

  defp normalize_method(method) when is_atom(method), do: method
  defp normalize_method(method) when is_binary(method) do
    method |> String.to_atom
  end
  defp normalize_method(method) when is_list(method) do
    method |> List.to_atom
  end

  def path_type(path) when is_binary(path) do
    type =
      cond do
        # Test for hidden first because we just want to skip them based on
        # their path, irrespective of their actual file status
        is_hidden?(path) ->
          :hidden
        !File.exists?(path) ->
          :new
        File.regular?(path) ->
          :file
        File.dir?(path) ->
          :directory
        true ->
          :special
      end
    {type, path}
  end
  def path_type(arg(pathinfo: :undefined)) do
    :none
  end
  def path_type(arg(docroot: docroot, pathinfo: pathinfo)) do
    [to_string(docroot), to_string(pathinfo)] |> Path.join |> path_type
  end

  defp is_hidden?(path) do
    case Path.basename(path) do
      <<".", _::binary>> ->
        true
      _ ->
        false
    end
  end
end
