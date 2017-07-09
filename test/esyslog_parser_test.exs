defmodule SyslogParserTest do
  use ExUnit.Case
  alias Syslog.Parser
  doctest Syslog.Parser

  test "parses entry without hostname" do
    result = Parser.parse('<12>Jul  7 16:05:00.12312 tag[123]: a message')

    assert result.hostname == "localhost"
    assert result.severity == :warn
    assert result.facility == :user
  end

  test "parses entry with hostname" do
    result = Parser.parse('<12>Jul  7 16:05:00.12312 myhostname tag[123]: a message')

    assert result.hostname == "myhostname"
    assert result.severity == :warn
    assert result.facility == :user
  end

  test "parses tag into components from an entry without hostname" do
    result = Parser.parse('<12>Jul  7 16:05:00.12312 tag[123]: a message')

    assert result.hostname == "localhost"
    assert result.process == "tag"
    assert result.pid == "123"
    assert result.message == "a message"
    assert result.severity == :warn
    assert result.facility == :user
  end

  test "parses tag into components from an entry with hostname" do
    result = Parser.parse('<12>Jul  7 16:05:00.12312 myhostname tag[123]: a message')

    assert result.hostname == "myhostname"
    assert result.process == "tag"
    assert result.pid == "123"
    assert result.message == "a message"
    assert result.severity == :warn
    assert result.facility == :user
  end

  test "parses date and time into components from an entry with hostname" do
    year = NaiveDateTime.utc_now().year
    result = Parser.parse('<12>Jul  7 16:05:00.12312 myhostname tag[123]: a message')

    assert result.hostname == "myhostname"
    assert result.datetime == NaiveDateTime.from_iso8601("#{year}-07-07 16:05:00.123120") |> elem(1)
    assert result.severity == :warn
    assert result.facility == :user
  end

  test "parses macOS take one" do
    result = Parser.parse('<4>Dec 20 16:27:32 ccabanilla-mac com.apple.launchd.peruser.501[522] (org.apache.couchdb[59972]): Exited with exit code: 1')

    assert result.priority == 4
    assert result.severity == :warn
    assert result.facility == :kern
    assert result.hostname == "ccabanilla-mac"
    assert result.process == "com.apple.launchd.peruser.501"
    assert result.pid == "522"
  end

  test "parses macOS take two" do
    result = Parser.parse('<5>Dec 20 16:27:32 ccabanilla-mac [0x0-0x99099].com.fluidapp.FluidInstance.Gmail[32480]: Sun Dec 20 16:27:32 ccabanilla-mac FluidInstance[32480] <Error>: kCGErrorIllegalArgument: CGSGetWindowBounds: NULL window')

    assert result.priority == 5
    assert result.severity == :notice
    assert result.facility == :kern
    assert result.hostname == "ccabanilla-mac"
    assert result.process == "[0x0-0x99099].com.fluidapp.FluidInstance.Gmail"
    assert result.pid == "32480"
  end

  test "parses entry with key-value data" do
    result = Parser.parse('<12>Jul  7 16:05:00.12312 myhostname tag[123]: a message owner=root uid=0 home="/home/Joseph Benden"')

    assert result.hostname == "myhostname"
    assert result.severity == :warn
    assert result.facility == :user
    assert Map.fetch!(result.kvps, "owner") == "root"
    assert Map.fetch!(result.kvps, "uid") == "0"
    assert Map.fetch!(result.kvps, "home") == "/home/Joseph Benden"
  end
end
