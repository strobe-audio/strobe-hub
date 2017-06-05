defmodule Elvis.Router do
  use Elvis.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    # plug :fetch_session
    # plug :fetch_flash
    # plug :protect_from_forgery
    # plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope path: "/collections" do
    forward "/", Peel.Webdav
  end

  scope "/", Elvis do
    pipe_through :browser # Use the default browser stack

    get "/layout", PageController, :layout
    get "/*path", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", Elvis do
  #   pipe_through :api
  # end
end
