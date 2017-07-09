defmodule Syslog.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Syslog.Server, []),
    ]

    opts = [strategy: :one_for_one, name: Syslog.Supervisor]
    Supervisor.start_link children, opts
  end
end