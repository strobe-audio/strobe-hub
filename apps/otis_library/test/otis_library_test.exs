defmodule TestLibrary do
  use Otis.Library, namespace: "test"
end

defmodule OtisLibraryTest do
  use ExUnit.Case


  test "#url encodes individual path elements" do
    assert TestLibrary.url(["this", "/that"]) == "test:this/%2Fthat"
  end

  test "#split decodes path elements" do
    assert TestLibrary.split("this/%2Fthat") == ["this", "/that"]
  end
end
