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
          # Extract repo (DID) from the commit
          repo_did = full_msg["commit"]["repo"]
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

  # defp derive_youtube_embed_link(skeet, record) when is_binary(skeet) do
  #   uri =
  #     case record do
  #       %{
  #         "record" => %{
  #           "embed" => %{
  #             "external" => %{
  #               "uri" => uri
  #             }
  #           }
  #         }
  #       } ->
  #         uri

  #       _ ->
  #         nil
  #     end

  #   if uri do
  #     if String.contains?(uri, "youtube.com") || String.contains?(uri, "youtu.be") do
  #       {:ok, uri}
  #     end
  #   end
  # end

  defp generate_id do
    :crypto.strong_rand_bytes(10) |> Base.encode16(case: :lower)
  end

  def handle_disconnect(%{reason: {:local, reason}}, state) do
    Logger.info("Local close with reason: #{inspect(reason)}")
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    super(disconnect_map, state)
  end
end
