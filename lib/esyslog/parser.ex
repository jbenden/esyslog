defmodule Syslog.Parser do
  @moduledoc """
  Module to handle the parsing of various acceptable forms of a Syslog message
  as described in [RFC3164](https://tools.ietf.org/html/rfc3164) and
  [RFC5426](https://tools.ietf.org/html/rfc5426). Additionally, various other
  forms of syslog messages are accepted, as found "in the wild".

  Improperly formatted Syslog messages are normalized while parsing, so that
  the output `Syslog.Entry` returned is completely populated. The methods
  for normalization are handled in the manner described in the RFCs above.

  The parser also handles a special form of structured data content, which is
  a form that pre-dates [RFC5424](https://tools.ietf.org/html/rfc5424). All
  key-value pairs found inside a message
  are extracted in to the `Syslog.Entry` returned, under the `kvps` Map
  field.
  """

  @doc """
  Parses a binary blob containing a Syslog Message.

  Returns `Syslog.Entry`.

  ## Examples

      iex> Syslog.Parser.parse('<12>Jul  7 16:05:00.12312 myhostname tag[123]: a message')
      %Syslog.Entry{arrival_datetime: nil, datetime: ~N[2017-07-07 16:05:00.123120],
       facility: :user, hostname: "myhostname", ip: nil, kvps: %{},
       message: "a message", pid: "123", port: nil, priority: 12, process: "tag",
       severity: :warn}

  """
  @spec parse(binary()) :: Syslog.Entry.t
  def parse(raw) do
    state = %{priority: [], datetime: [], hostname: nil, tag: nil, process: nil, pid: nil, kvps: %{}}

    {:ok, message, state} =
      with {raw, state} <- parse_priority(raw, state),
           {raw, state} <- parse_datetime(raw, state),
           {raw, state} <- parse_host_and_tag(raw, state),
           {raw, state} <- parse_kw(raw, state),
           do: {:ok, raw, state}

    # Priority is two components, split them
    {priority, _} =
      state.priority
      |> to_string
      |> Integer.parse

    {facility, severity} = {decode_facility(div(priority, 8)),
                            decode_severity(rem(priority, 8))}

    %Syslog.Entry{datetime: state.datetime,
                  priority: priority,
                  facility: facility,
                  severity: severity,
                  hostname: state.hostname,
                  process: state.process,
                  pid: state.pid,
                  message: message,
                  kvps: state.kvps}
  end

  @spec decode_facility(integer) :: atom
  defp decode_facility(facility) do
    case facility do
      0  -> :kern
      1  -> :user
      2  -> :mail
      3  -> :system
      4  -> :auth
      5  -> :internal
      6  -> :lpr
      7  -> :nns
      8  -> :uucp
      9  -> :clock
      10 -> :authpriv
      11 -> :ftp
      12 -> :ntp
      13 -> :audit
      14 -> :alert
      15 -> :clock2 # ?
      16 -> :local0
      17 -> :local1
      18 -> :local2
      19 -> :local3
      20 -> :local4
      21 -> :local5
      22 -> :local6
      23 -> :local7
      _  -> :undefined
    end
  end

  @spec decode_severity(integer) :: atom
  defp decode_severity(severity) do
    case severity do
      0 -> :emerg
      1 -> :alert
      2 -> :crit
      3 -> :err
      4 -> :warn
      5 -> :notice
      6 -> :info
      7 -> :debug
      _ -> :undefined
    end
  end

  @spec parse_priority(list(binary()), map()) :: {nonempty_maybe_improper_list(), map()}
  defp parse_priority([h | t], state) do
    cond do
      h == ?< -> parse_priority_1(t, state)
      true -> raise ArgumentError, "invalid priority opening character"
    end
  end

  @spec parse_priority_1(list(binary()), map()) :: {nonempty_maybe_improper_list(), map()}
  defp parse_priority_1([h | t], %{priority: p} = state) do
    cond do
      h >= ?0 and h <= ?9 -> parse_priority_1(t, %{state | priority: p ++ [h]})
      h == ?> -> {t, state}  # parse_datetime(state, t) # next state
    end
  end

  @months ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  @spec parse_datetime(binary, map) :: {nonempty_maybe_improper_list(), map()}
  defp parse_datetime(chars, state) do
    case Regex.run(~r/(?<month>Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s(?|(?:\s)(?<day>[1-9])?|(?<day>[1-9]\d))\s(?<hour>[0-2]\d):(?<minute>[0-5][0-9]):(?<second>[0-5][0-9])(?|(?:\.)(?<fractional_seconds>\d{1,9})?|)\s/iu, to_string(chars)) do
      nil -> raise ArgumentError, "invalid date and time formatting"
      elements ->
        # first is the entire match sequence
        continuation = to_charlist(String.slice(to_string(chars), String.length(hd(elements))..-1))

        year = NaiveDateTime.utc_now().year
        month = Enum.find_index(@months, fn(m) -> m == Enum.at(elements, 1) end) + 1
        {day, _} = Enum.at(elements, 2) |> Integer.parse
        {hour, _} = Enum.at(elements, 3) |> Integer.parse
        {minutes, _} = Enum.at(elements, 4) |> Integer.parse
        {seconds, _} = Enum.at(elements, 5) |> Integer.parse
        {microseconds, _} =
          (Enum.at(elements, 6) || "")
          |> String.pad_trailing(6, "0")
          |> to_charlist
          |> Enum.take(6)
          |> to_string
          |> Integer.parse

        {:ok, dt} = NaiveDateTime.new(year, month, day, hour, minutes, seconds, microseconds)

        {continuation, %{state | datetime: dt}}
    end
  end

  @spec parse_host_and_tag(binary, map) :: {[binary], map()}
  defp parse_host_and_tag(chars, state) do
    elements = to_string(chars)
    |> String.split

    # first element could be a hostname
    [h | t] = elements

    {cont, state} =
      case Regex.run(~r/^(?<process>.+)\[(?<pid>\d+)\]:?$/u, h) do
        nil -> {true, %{state | hostname: h}}
        elements ->
          {false, %{state | tag: h, hostname: "localhost", process: Enum.at(elements, 1), pid: Enum.at(elements, 2)}}
      end

    case cont do
      false ->
        {t, state}
      true ->
        [h1 | t1] = t
        case Regex.run(~r/^(?<process>.+)\[(?<pid>\d+)\]:?$/u, h1) do
          nil -> {t, state}
          elements ->
            {t1, %{state | tag: h1, process: Enum.at(elements, 1), pid: Enum.at(elements, 2)}}
        end
    end
  end

  @spec parse_kw(binary, map) :: {binary, map}
  defp parse_kw(chars, state) do
    elements =
      Regex.scan(~r/\s?(([a-zA-Z0-9]+)=("(?:[^"\\]|\\.)*"|[^ ]+))\s?/,
        Enum.join(chars, " "))

    state =
      Enum.reduce(elements, state, fn(s, state) ->
        k = Enum.at(s, 2)
        v = Enum.at(s, 3)
        %{state | kvps: Map.put(state.kvps, k, v |> String.trim("\"")) }
      end)

    {Enum.join(chars, " "), state}
  end
end
