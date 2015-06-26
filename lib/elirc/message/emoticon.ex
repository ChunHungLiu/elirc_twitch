defmodule Elirc.Emoticon do
  alias Beaker.Counter
  alias Beaker.TimeSeries

  @doc """
  Starts the Emoticon process

  ## Example
  start_link()
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    start_buckets()
    start_metrics()

    {:ok, []}
  end

  @doc """
  Starts running metrics on emoticons
  """
  def start_metrics() do
    # Every 1 min, flush channel metric count
    Quantum.add_job("*/1 * * * *", fn ->
      Elirc.Emoticon.process_metrics()
    end)
  end

  def handle_cast("fetch_and_import", state) do
    fetch_and_import()

    {:noreply, state}
  end

  @doc """
  Starts the ets buckets
  """
  def start_buckets() do
    :ets.new(:emoticons, [
      :ordered_set,
      :named_table,
      :public,
      {:read_concurrency, true}
    ])

    :ets.new(:emote_global, [
      :ordered_set,
      :named_table,
      :public,
      {:read_concurrency, true}
    ])

    :ets.new(:emote_sets, [
      :ordered_set,
      :named_table,
      :public,
      {:read_concurrency, true}
    ])

    :ets.new(:emote_images, [
      :ordered_set,
      :named_table,
      :public,
      {:read_concurrency, true}
    ])

    :ets.new(:emote_subscribers, [
      :ordered_set,
      :named_table,
      :public,
      {:read_concurrency, true}
    ])
  end

  @doc """
  Fetch a list of global emoticons, and parse the json
  """
  def fetch_global_emoticons() do
    "http://twitchemotes.com/api_cache/v2/global.json"
      |> HTTPoison.get!()
      |> Map.fetch!(:body)
      |> Poison.decode!()
      |> Map.fetch!("emotes")
  end


  @doc """
    Fetch a list of subscriber emoticons, and parse the json
  """
  def fetch_subscriber_emoticons() do
    "http://twitchemotes.com/api_cache/v2/subscriber.json"
      |> HTTPoison.get!()
      |> Map.fetch!(:body)
      |> Poison.decode!()
      |> Map.fetch!("channels")
  end

  @doc """
  Fetch a list of images for emoticons, and parse the json
  """
  def fetch_emoticon_images() do
    "http://twitchemotes.com/api_cache/v2/images.json"
      |> HTTPoison.get!()
      |> Map.fetch!(:body)
      |> Poison.decode!()
      |> Map.fetch!("images")
  end

  @doc """
  Fetch a sets list from twitchemotes.com, and parse the json
  """
  def fetch_emoticon_sets() do
    "http://twitchemotes.com/api_cache/v2/sets.json"
      |> HTTPoison.get!()
      |> Map.fetch!(:body)
      |> Poison.decode!()
      |> Map.fetch!("sets")
  end

  @doc """
  Fetch emote lists and import to ETS
  """
  def fetch_and_import() do
    fetch_global_emoticons()
      |> Enum.each fn ({k, v}) -> save(:emote_global, k, v) end

    fetch_subscriber_emoticons()
      |> Enum.each fn ({k, v}) -> save(:emote_subscribers, k, v) end

    fetch_emoticon_images()
      |> Enum.each fn (tup) -> save(:emote_images, tup) end

    fetch_emoticon_sets()
      |> Enum.each fn (tup) -> save(:emote_sets, tup) end
  end


  @doc """
  Save emote to main list of emoticons

  ## Example
  save(:emoticons, "danBad", %{"image_id" => 234}})
  """
  defp save(bucket, key, value) do
    if Map.has_key?(value, "emotes") do
      value
        |> Map.fetch!("emotes")
        |> Enum.each fn (emote) -> save_main_emote(emote) end
    else
      save_main_emote({key, value})
    end
  end

  @doc """
  Saves the emote to the main dataset

  ## Example
  save_main_emote(%{"4Head": {"description": "This is the face of a popular Twitch streamer. twitch.tv/cadburryftw",
     "image_id": 354
  }})
  """
  defp save_main_emote(emote) do
    case emote do
      %{"code" => code, "image_id" => image_id} ->
        save(:emoticons, {code, %{"image_id" => image_id}})
      emote -> save(:emoticons, emote)
    end
  end

  defp save(bucket, tup) do
    :ets.insert(bucket, tup)
  end

  defp lookup(value, bucket) do
    :ets.lookup(bucket, value)
  end

  @doc """
  Get all the emoticons, global and subscribers
  """
  def get_all!() do
    :ets.match(:emoticons, :"$1")
  end

  @doc """
  Gets the emoticon from the main list

  ## Examples
  get("DansGame")
  get("danBad")
  """
  def get(emoticon) do
    lookup(emoticon, :emoticons)
      |> handle_result()
  end

  @doc """
  Gets the global emoticon result

  ## Example
  get_global_emote("DansGame")
  """
  def get_global_emote(emoticon) do
    lookup(emoticon, :emote_global)
      |> handle_result()
  end

  @doc """
  Gets the set result

  ## Examples
  get_set("203")
  """
  def get_set(set) do
    lookup(set, :emote_sets)
      |> handle_result()
  end

  @doc """
  Get image details from image id

  ## Example
  get_image(2933)
  """
  def get_image(image_id) do
    result = image_id
      |> Integer.to_string()
      |> lookup(:emote_images)
      |> handle_result
  end

  @doc """
  Gets the subscriber, with emotes and channel info

  ## Example
  get_subscriber("test_channel")
  """
  def get_subscriber(channel) do
    lookup(channel, :emote_subscribers)
  end

  def handle_result([result]) do
    IO.puts "result in list"
    IO.inspect result
    result
  end

  def handle_result(result) do
    IO.puts "catch all"
    IO.inspect result

    result
  end

  @doc """
  Gets the subscriber emotes

  ## Example
  get_subscriber_emotes("test_channel")
  """
  def get_subscriber_emotes(channel) do
    get_subscriber(channel)
      |> Map.fetch!("emotes")
  end
# {
#     "code" =>  "movember",
#     "channel" => "beyondthesummit",
#     "set" => 23
# },
  def get_image_details(image_id) do
    case get_image(image_id) do
      {_, value} -> value
      [] -> %{}
    end
  end

  @doc """
  Gets details about the emoticon

  ## Example
  get_emoticon_details("danBad")
  """
  def get_emoticon_details(emoticon) do
    get_image_id(emoticon)
      |> get_image_details
  end

  @doc """
  Gets the image_id for the emoticon

  ## Example
  get_image_id("DansGame")
  """
  def get_image_id(emoticon) do
    image = get(emoticon)

    if image == [] do
      0
    end

    case image do
      {_, image} -> parse_image!(image)
      [] -> 0
    end
  end

  @doc """
  Parse map for image_id

  ## Example
      iex> Elirc.Emoticon.parse_image!(%{"image_id" => 2})
      2
  """
  def parse_image!(image) do
    case image do
      %{"image_id" => image_id} -> image_id
    end
  end

  @doc """

  ## Examples
      iex> Elirc.Emoticon.has_emote?("danBat danBad", "danBad")
      true

      iex> Elirc.Emoticon.has_emote?("danBat danThink", "danBad")
      false
  """
  def has_emote?(message, emote) do
    if find_emote_in_message!(message, get_emote(emote)) == [] do
      false
    else
      # IO.puts "Found Emote! #{message} (#{get_emote(emote)})"
      true
    end
  end

  @doc """
  Finds any provided emotes in the message

  ## Examples
      iex> Elirc.Emoticon.find_emotes!("danBad", [[{"danYay", %{"image_id" => 4604}}], [{"150Cap", %{"image_id" => 32727}}], [{"150Cappa", %{"image_id" => 21542}}], [{"danBad", %{"image_id" => 21543}}]])
      [%{"danBad" => %{"count" => 1}}]
  """
  def find_emotes!(message, emotes) when is_list(emotes) do
    x = emotes
      |> Enum.map(fn ([{emote, _}]) -> find_emote_in_message!(message, emote) end)
      |> Enum.reject(fn (emotes) -> length(emotes) == 0 end)
      |> Enum.map(fn (emotes) -> Map.put(%{}, hd(emotes), %{"count" => length(emotes)}) end)

    # IO.inspect x

    x
  end

  @doc """
  Processes metrics for all emotes on all channels
  """
  def process_metrics() do
    Elirc.Emoticon.get_all!()
      |> Enum.each(fn (emote) ->
          emoticon = get_emote(emote)

          count = Counter.get(emoticon)

          case count do
            nil -> nil
            count -> save_sample(count, emoticon)
          end
        end)
  end

  @doc """
  Saving sample count for the emoticon in the TimeSeries

  ## Example
  save_sample(3, "danBad")
  """
  def save_sample(count, emoticon) do
    # debug "Processing Metrics for #{emoticon}"
    TimeSeries.sample(emoticon, count)

    Beaker.TimeSeries.get(emoticon)
      # |> IO.inspect

    Counter.set(emoticon, 0)
  end

  @doc """
  Finds any of the emote in the message

  ## Examples
      iex> Elirc.Emoticon.find_emote_in_message!("danBat danBad", "danBad")
      ["danBad"]
  """
  def find_emote_in_message!(message, emote) do
    message
      |> String.split()
      |> Enum.reject(fn (part) -> part != emote end)
  end

  @doc """

  ## Examples
      iex> Elirc.Emoticon.get_emote([{"danBad", %{"image_id" => 32728}}])
      "danBad"
  """
  def get_emote([{emote, _}]) do
    emote
  end

  @doc """

  ## Examples
      iex> Elirc.Emoticon.get_emote({"danBad", %{"image_id" => 32728}})
      "danBad"
  """
  def get_emote({emote, _}) do
    emote
  end

  @doc """

  ## Examples
      iex> Elirc.Emoticon.get_emote(["danBad"])
      "danBad"
  """
  def get_emote([emote]) do
    emote
  end

  @doc """

  ## Examples
      iex> Elirc.Emoticon.get_emote("danBad")
      "danBad"
  """
  def get_emote(emote) do
    emote
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end