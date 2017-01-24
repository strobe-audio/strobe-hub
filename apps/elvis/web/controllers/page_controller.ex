defmodule Elvis.PageController do
  use Elvis.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
  def layout(conn, _params) do
    render conn, "layout.html"
  end
end
