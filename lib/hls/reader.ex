defprotocol HLS.Reader do
  def read!(reader, url)
  def read_with_expiry!(reader, url)
end
