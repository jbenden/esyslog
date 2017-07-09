defmodule SyslogTest do
  use ExUnit.Case
  doctest Syslog

  defmodule TestEvent do
    @moduledoc false

    @behaviour Syslog.Event

    require Logger
    use Syslog.Event

    def on_syslog(msg) do
      Logger.info "msg=#{inspect msg}"
      send Application.get_env(:esyslog, :test_pid, nil), msg
    end
  end

  setup do
  #  Syslog.Server.start_link
    #@pid self()
    Application.put_env(:esyslog, :test_pid, self())
    Application.stop(:esyslog)
    Application.put_env(:esyslog, :handler, "SyslogTest.TestEvent")
    Application.start(:esyslog)
  end

  test "functionally works over UDP socket" do
    packet = '<12>Jul  7 16:05:00.12312 myhostname tag[123]: a message'
    {:ok, socket} = :gen_udp.open(0, [active: false, mode: :binary])
    {:ok, local_port} = :inet.port(socket)
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 12_000, packet)

    # Process.sleep(2_000)
    receive do
      msg ->
        assert !is_nil(msg)
        assert msg.ip == {127, 0, 0, 1}
        assert msg.port == local_port
        assert msg.priority == 12
        assert msg.facility == :user
        assert msg.severity == :warn
        assert msg.hostname == "myhostname"
        assert msg.message == "a message"
        assert msg.process == "tag"
        assert msg.pid == "123"
    after
      2_000 -> raise "Timeout"
    end
  end
end
