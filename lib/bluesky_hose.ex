defmodule NathanForUs.BlueskyHose do
  use WebSockex
  require Logger

  alias NathanForUs.Social

  def start_link(opts \\ []) do
    # Create ETS table if it doesn't exist
    # :ets.new(@table_name, [:named_table, :ordered_set, :public, read_concurrency: true])

    WebSockex.start_link(
      "wss://bsky-relay.c.theo.io/subscribe?wantedCollections=app.bsky.feed.post",
      __MODULE__,
      :fake_state,
      opts
    )
  end

  def handle_connect(_conn, _state) do
    {:ok, 0}
  end

  def handle_frame({:text, msg}, state) do
    msg = Jason.decode!(msg)

    case msg do
      %{"commit" => record = %{"record" => %{"text" => skeet}}} = full_msg ->
        if contains_nathan_fielder?(skeet) do
          # Extract DID from the top-level message
          repo_did = full_msg["did"]
          Logger.info("Found Nathan Fielder mention from DID: #{inspect(repo_did)}")
          
          # Check for embeds
          embed_info = get_in(record, ["record", "embed"])
          if embed_info do
            Logger.info("Post contains embed: #{inspect(embed_info)}")
          end
          
          record_with_did = Map.put(record, "repo", repo_did)
          
          case Social.create_bluesky_post_from_record(record_with_did) do
            {:ok, _post} ->
              Logger.info("Saved Nathan Fielder mention: #{String.slice(skeet, 0, 100)}...")
            {:error, reason} ->
              Logger.error("Failed to save Nathan Fielder mention: #{inspect(reason)}")
          end
        end
      _ ->
        nil
    end

    {:ok, state + 1}
  end

  defp contains_nathan_fielder?(text) when is_binary(text) do
    downcased = String.downcase(text)
    String.contains?(downcased, "nathan fielder")
  end


  def handle_disconnect(%{reason: {:local, reason}}, state) do
    Logger.info("Local close with reason: #{inspect(reason)}")
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    super(disconnect_map, state)
  end
end
