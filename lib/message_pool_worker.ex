defmodule Elirc.MessagePool.Worker do
  alias Elirc.Message

  def start_link([client, token]) do
    GenServer.start_link(__MODULE__, [client, token], [])
  end

  def init([client, token]) do
    {:ok, %{client: client, token: token}}
  end

  def handle_cast([channel, user, message], state) do
    process(message, channel, state)

    {:noreply, state}
  end

  def process(message, channel, state) do
    case String.lstrip(message) do
      "!" <> command -> command(command, channel, state)
      message -> process_message_for_data(message)
    end
  end

  @doc """

  ## Example
  Elirc.MessagePool.Worker.process_message_for_data("danBad danBat")
  """
  def process_message_for_data(message) do
    emotes = Elirc.Emoticon.get_all!()
    words = ["danThink", "deIlluminati"]

    message
      |> Message.find_emotes(emotes)
      |> Message.find_words(words)
      # |> Message.find_users(users)
      |> Message.find_links()
      |> Message.find_spam()
  end

  def command(command, channel, state) do
    case parse_command(command) do
      {:say, message} -> Message.say(message, channel, state.client)
      {:sound, sound} -> play_sound(sound)
      {:cmd, cmd} -> run_command(cmd, channel)
      _ -> :ok
    end
  end

  def play_sound(sound) do
    Elirc.Sound.play(sound)
  end

  def run_command(cmd, channel) do
    Elirc.Command.run(cmd, channel)
  end

  def command_alias(cmd_alias) do
    case cmd_alias do
      ["bealight"] -> ["bealright"]
      ["bot"] -> ["elirc"]
      ["glacier"] -> ["theme"]
      ["xfile"] -> ["xfiles"]
      ["h"] -> ["help"]
      ["coming"] -> ["getsmeeverytime"]
      ["wtf"] -> ["talkingabout"]
      ["beatit"] -> ["beat_it"]
      ["waithere"] -> ["waitthere"]
      ["63"] -> ["speedlimit"]
      ["65"] -> ["speedlimit"]
      ["danThink"] -> ["dont"]
      cmd -> cmd
    end
  end

  def parse_command(command) do
    case String.split(command) |> command_alias() do
      ["hello"] -> {:say, "Hello"}
      ["help"] -> {:say, "You need help."}
      ["engage"] -> {:sound, "engage"}
      ["dont"] -> {:sound, "dont"}
      ["speedlimit"] -> {:sound, "speedlimit"}
      ["yeahsure"] -> {:sound, "yeahsure"}
      ["xfiles"] -> {:sound, "xfiles"}
      ["wedidit"] -> {:sound, "wedidit"}
      ["toy"] -> {:sound, "toy"}
      ["waitthere"] -> {:sound, "waitthere"}
      ["bealright"] -> {:sound, "bealright"}
      ["injuriesemotional"] -> {:sound, "injuriesemotional"}
      ["getsmeeverytime"] -> {:sound, "getsmeeverytime"}
      ["talkingabout"] -> {:sound, "talkingabout"}
      ["beat_it"] -> {:sound, "beat_it"}
      ["whatsthat"] -> {:sound, "whatsthat"}
      ["stupid"] -> {:sound, "stupid"}
      ["yadda"] -> {:sound, "yadda"}
      ["follower"] -> {:cmd, "follower"}
      ["followed"] -> {:cmd, "followed"}
      ["elixir"] -> {:say, "Elixir is a dynamic, functional language designed for building scalable and maintainable applications. http://elixir-lang.org/"}
      ["elirc"] -> {:say, "https://github.com/rockerBOO/elirc_twitch"}
      ["soundlist"] -> {:say, "injuriesemotional, getsmeeverytime, talkingabout, beat_it, stupid, yadda, engage, dont, speedlimit, yeahsure, xfiles, wedidit, toy, waitthere, bealright, whatsthat"}
      ["whatamidoing"] -> {:say, "Working on a Twitch Bot in Elixir. Elixir works well with co-currency and messages. This is ideal for IRC chat processing."}
      ["itsnotaboutsyntax"] -> {:say, "http://devintorr.es/blog/2013/06/11/elixir-its-not-about-syntax/"}
      ["excitement"] -> {:say, "http://devintorr.es/blog/2013/01/22/the-excitement-of-elixir/"}
      ["commands"] -> {:say, "!(hello, elixir, theme, resttwitch, bot, soundlist, whatamidoing, itsnotaboutsyntax, excitement, song, flip)"}
      ["twitchapi"] -> {:say, "https://github.com/justintv/Twitch-API/blob/master/v3_resources/"}
      ["resttwitch"] -> {:say, "https://github.com/rockerBOO/rest_twitch"}
      ["theme"] -> {:say, "http://glaciertheme.com/"}
      ["flip"] -> {:say , "(╯°□°）╯︵┻━┻"}
      ["song"] -> {:cmd, "song"}
      ["emote" | emote] -> {:cmd, Enum.join(["emote" | emote], " ")}
      _ -> nil
    end
  end

  def handle_info(reason, state) do
    IO.inspect reason

    {:noreply, state}
  end

  def terminate(reason, state) do
    IO.inspect reason
    :ok
  end
end