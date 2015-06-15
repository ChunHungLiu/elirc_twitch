defmodule Elirc do
  use Supervisor

  def init([state]) do
    {:ok, state}
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # {:ok, client} = ExIrc.Client.start_link [debug: true]
    {:ok, client} = ExIrc.Client.start_link

  	children = [
      # Define workers and child supervisors to be supervised
      worker(Elirc.Handler.Connection, [client]),
      # here's where we specify the channels to join:
      worker(Elirc.Handler.Login, [client, ["#rockerboo"]]),
      worker(Elirc.Handler.Join, [client]),
      worker(Elirc.Handler.Message, [client])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elirc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end