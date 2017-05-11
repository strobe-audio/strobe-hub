defmodule Peel.Webdav.Supervisor do
  use     Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def enabled?(opts) do
    Keyword.get(opts, :enabled, true)
  end

  def init(opts) do
    dav = case webdav_spec(opts) do
      {:ok, sc, gc, yaws_child_specs} ->
        yaws_child_specs ++ [
          worker(Peel.Webdav.Config, [sc, gc, opts], restart: :transient),
        ]
      _ -> []
    end

    children = dav ++ [
      worker(Peel.Webdav.Modifications, [opts]),
    ]
    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp webdav_spec(opts) do
    opts |> enabled? |> _webdav_spec(opts)
  end

  defp _webdav_spec(false, _opts), do: :ignore
  defp _webdav_spec(true, opts) do
    docroot = Keyword.get(opts, :root) |> ensure_docroot() |> to_charlist
    port = Keyword.get(opts, :port, 8080)

    Logger.info "Configuring WebDAV server at #{to_string(docroot) |> inspect} on port #{port}"

    server_conf = [
      docroot: docroot,
      port: port,
      listen: {0, 0, 0, 0},
      appmods: [{'/', Peel.Webdav.Handler}],
      auth: [
        docroot: docroot,
        dir: '/',
        realm: 'Strobe Library',
        users: [strobe_user()],
      ],
      flags: [
        access_log: false,
        auth_skip_docroot: true,
        auth_log: false,
      ],
      # opaque is passed through to the appmod in the `arg` record -- might be
      # useful at some point...
      # opaque: %{ something: :here },
    ]
    global_conf = [
      runmods: [:yaws_runmod_lock],
      flags: [
        copy_error_log: false,
        use_erlang_sendfile: true,
        use_yaws_sendfile: false,
        # tty_trace: true,
        # debug: true,
      ],
    ]
    server_id = 'peel-webdav'

    :yaws_api.embedded_start_conf(docroot, server_conf, global_conf, server_id)
  end

  @username 'strobe'
  @password 'audio'
  @salt     ''

  defp strobe_user do
    {@username, :md5, @salt, :crypto.hash(:md5, [@salt, @password])}
  end

  defp ensure_docroot(nil), do: raise "Invalid docroot `nil`"
  defp ensure_docroot(docroot) do
    docroot |> to_string |> File.mkdir_p
    docroot
  end
end
