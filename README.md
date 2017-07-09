# Syslog

Simple collector for the Syslog Message Protocol, as described by [The BSD syslog Protocol; RFC3164](https://tools.ietf.org/html/rfc3164).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `esyslog` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:esyslog, "~> 0.1.0"}]
end
```

After adding `esyslog` as a dependency, ensure it is started before your own
application in `mix.exs`:

```elixir
def application do
  [extra_applications: [:esyslog]]
end
```

## Usage

Fairly simple. Create your own module that implements the behaviour `Syslog.Event`
and then register your module in the `Application` environment; before your own
application starts. Eg:

```elixir
config :esyslog, handler: "MyApplication.Syslog.EventHandler"
```

## Configuration Options

The following configuration options are available, with their default value shown:

```elixir
config :esyslog,
  enabled: true,
  port: 10_000,
  handler: "Syslog.DefaultEvent"
```
