defmodule Plug.WebDav.Time do
  def format(datetime) when is_tuple(datetime) do
    datetime |> format_universal_time("+0000")
  end

  defp format_universal_time({{year, month, day}, {h, m, s}}, zone) do
    [ day(year, month, day), ", ",
      pad(day), " ", month(month), " ", to_string(year), " ",
      pad(h), ":", pad(m), ":", pad(s), " ", zone
    ]
  end

  defp pad(i) when i < 10, do: ["0", to_string(i)]
  defp pad(i), do: to_string(i)

  defp day(year, month, day) do
    int_to_wd(:calendar.day_of_the_week(year, month, day))
  end

  defp int_to_wd(1), do: "Mon"
  defp int_to_wd(2), do: "Tue"
  defp int_to_wd(3), do: "Wed"
  defp int_to_wd(4), do: "Thu"
  defp int_to_wd(5), do: "Fri"
  defp int_to_wd(6), do: "Sat"
  defp int_to_wd(7), do: "Sun"

  defp month(1), do: "Jan"
  defp month(2), do: "Feb"
  defp month(3), do: "Mar"
  defp month(4), do: "Apr"
  defp month(5), do: "May"
  defp month(6), do: "Jun"
  defp month(7), do: "Jul"
  defp month(8), do: "Aug"
  defp month(9), do: "Sep"
  defp month(10), do: "Oct"
  defp month(11), do: "Nov"
  defp month(12), do: "Dec"
end
