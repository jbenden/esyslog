defmodule Syslog.Server do
  @moduledoc false

  use GenServer
  require Logger

  # Client API

  @doc false
  def start_link() do
    enabled        = Application.fetch_env!(:esyslog, :enabled)
    port           = Application.fetch_env!(:esyslog, :port)
    handler_module = Application.fetch_env!(:esyslog, :handler)

    GenServer.start_link(__MODULE__, %{sup: nil, enabled: enabled, handler_module: handler_module, port: port, socket: nil})
  end

  @doc false
  @spec init(map()) :: {:ok, map()}
  def init(%{enabled: true, port: port} = state) do
    import Supervisor.Spec #, warn: false

    children = [
      supervisor(Task.Supervisor, [[name: Syslog.TaskSupervisor]])
    ]

    # Start a worker Task supervision tree, and restart on total failure
    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)

    # start udp accepts
    {:ok, socket} = :gen_udp.open port, [active: true, mode: :binary, reuseaddr: true]

    # return success with our state
    {:ok, %{state | sup: pid, socket: socket}}
  end

  @doc false
  def init(%{enabled: false} = state) do
    # We're not enabled, so return a dummy response
    {:ok, state}
  end

  @doc false
  @spec handle_info(map() | any(), map()) :: {:noreply, map()}
  def handle_info({:udp, _s, ip, port, raw}, state) do
    state
    |> handle_incoming(ip, port, raw)
    |> tuple_reply(:noreply)
  end

  @doc false
  def handle_info(_, state), do: {:noreply, state}

  @doc false
  @spec handle_incoming(map(), tuple(), integer(), binary()) :: map()
  defp handle_incoming(state, ip, port, packet) do
    # Create a Task for processing incoming UDP packet and add to supervisor tree
    {:ok, pid} =
      Task.Supervisor.start_child(Process.whereis(Syslog.TaskSupervisor),
        Module.concat([state.handler_module]),
        :handle,
        [ip, port, packet])

    # Ensure the newly created Task is the group leader for itself, to prevent crashes
    # taking down the entire supervision tree.
    true =
      try do
        Process.group_leader pid, pid
      rescue
        ArgumentError -> true
      end

    # Return our state!
    state
  end

  @doc false
  @spec tuple_reply(map(), atom()) :: {atom(), map()}
  defp tuple_reply(state, code) do
    {code, state}
  end
end
