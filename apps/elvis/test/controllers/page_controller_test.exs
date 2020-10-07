defmodule Elvis.PageControllerTest do
  use Elvis.ConnCase

  test "GET /" do
    conn = get(conn(), "/")
    assert html_response(conn, 200) =~ "Strobe"
  end

  test "GET / refs strobe.appcache" do
    conn = get(conn(), "/")
    assert html_response(conn, 200) =~ ~r{manifest="/strobe.appcache"}
  end
end
