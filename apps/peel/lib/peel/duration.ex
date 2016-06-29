defmodule Peel.Duration do
	@h 3600
	@m 60

  def hms_ms(duration_ms) do
    (duration_ms / 1000) |> round |> hms_s
  end

  def hms_s(s) do
    h = div(s, @h)
    s = s - h * @h
    m = div(s, @m)
    s = s - m * @m
		format(h, m, s)
  end

	def format(0, m, s) do
    "#{pad(m)}:#{pad(s)}"
	end

	def format(h, m, s) do
    "#{h}:#{pad(m)}:#{pad(s)}"
	end

  def pad(v) when is_integer(v) do
    v |> to_string |> pad
  end

  def pad(v) when is_binary(v) do
    String.pad_leading(v, 2, "0")
  end
end
