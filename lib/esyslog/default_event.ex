defmodule Syslog.DefaultEvent do
  @moduledoc false

  @behaviour Syslog.Event

  require Logger
  use Syslog.Event

  @doc false
  def on_syslog(msg) do
    :ok = Logger.info "msg=#{inspect msg}"
  end
end
