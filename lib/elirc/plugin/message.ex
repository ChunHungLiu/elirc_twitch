defmodule Elirc.Message do
  defmodule State do
    defstruct channel: "",
              message: "",
              client: nil
  end

  @doc """
  Say message to channel

  ## Example
  say("Hello", "#test_channel", ExIrc.Client, true)
  """
  def say(message, channel, config) do
    # debug "Saying #{message} to #{channel}"

    if noisy?(channel) do
      send_say(message, channel, config.client)
    else
      debug "Silenced... Say (#{channel}): #{message}"
    end
  end

  def noisy?(channel) do
    true
    opts = Elirc.Channel.pid(channel)
      |> Elirc.Channel.state()
      |> Map.fetch!(:opts)

    opts.noisy?
  end

  def whisper(user, message) do
    # IO.puts "Saying to user " <> user <> " message " <> message
    :whisper_irc |> ExIrc.Client.cmd("PRIVMSG #jtv :/w " <> user <> " " <> message)
  end

  @doc """
  Sends the message to the IRC server

  ## Example
  send_say("Hello", "#test_channel", ExIrc.Client)
  """
  def send_say(message, channel, client) do
    debug "Say (#{channel}): #{message}"

    # client |> ExIrc.Client.cmd("PRIVMSG .w " <> user <> " :" message)
    client |> ExIrc.Client.msg(:privmsg, channel, message)
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end