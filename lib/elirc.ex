defmodule Elirc do
  use Supervisor

  def init([state]) do
    {:ok, state}
  end

  def start(_type, _args) do
    import Supervisor.Spec

    {:ok, rest_client} = RestTwitch.Request.start

    # Start up the emoticon ETS
    {:ok, emoticon_pid} = Elirc.Emoticon.start_link()

    IO.puts "Fetching and importing emoticons..."

    GenServer.cast(emoticon_pid, "fetch_and_import")

    # Twitch OAuth2 Access Token
    token = System.get_env("TWITCH_ACCESS_TOKEN")

    {:ok, client} = ExIrc.Client.start_link [debug: true]

    # Twitch Channels
    channels = Application.get_env(:twitch, :channels) |> String.split(" ")

  	children = [
      # Handles connection actions in IRC
      worker(Elirc.Handler.Connection, [client]),
      # Handles Login actions
      # worker(Elirc.Handler.Login, [client, ["#rockerboo", "#jonbams", "#lirik", "#itmejp"]]),
      worker(Elirc.Handler.Login, [client, channels]),
      # worker(Elirc.Handler.Join, [client]),
      worker(Elirc.Handler.Message, [client, token]),
      worker(Elirc.Handler.Names, [client]),
      worker(Elirc.Channel.Supervisor, [client]),
      worker(Elirc.MessagePool.Supervisor, [client, token])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elirc.Supervisor]
    Supervisor.start_link(children, opts)
    # supervisor(children, opts)
  end

  def terminate(reason, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    ExIrc.Client.quit state.client, "Goodbye, cruel world."
    ExIrc.Client.stop! state.client
    :ok
  end
end