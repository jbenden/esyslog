defmodule Syslog.Event do
  @moduledoc """
  As incoming Syslog Messages are received, they are passed to the
  `c:Syslog.Event.on_syslog/1` callback.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      require Logger

      @before_compile Syslog.Event
    end
  end

  # Callback/Behaviour to be implemented in order to receive incoming Syslog messages
  @doc """
  User function to handle an incoming Syslog decoded message.
  """
  @callback on_syslog(msg :: Syslog.Entry.t) :: any

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      @spec handle(tuple, integer, binary) :: any
      def handle(ip, port, packet) do
        packet
        |> to_charlist
        |> Syslog.Parser.parse
        |> adjust_entry(ip, port)
        |> on_syslog
      end

      @doc false
      @spec adjust_entry(Syslog.Entry.t, tuple, integer) :: Syslog.Entry.t
      defp adjust_entry(state, ip, port) do
        %Syslog.Entry{state | arrival_datetime: NaiveDateTime.utc_now(), ip: ip, port: port}
      end
    end
  end
end
