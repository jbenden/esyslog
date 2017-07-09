defmodule Syslog.Entry do
  @moduledoc """
  Wraps a parsed Syslog Message in to each message component.
  """

  @type t :: %__MODULE__{ip: tuple, port: integer, arrival_datetime: NaiveDateTime.t, priority: integer, facility: integer, severity: integer, datetime: NaiveDateTime.t, hostname: binary, process: binary, pid: binary, message: binary, kvps: map}
  defstruct [:ip, :port, :arrival_datetime, :priority, :facility, :severity, :datetime, :hostname, :process, :pid, :message, :kvps]
end
