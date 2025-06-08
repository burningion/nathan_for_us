defmodule NathanForUs.BlueskyAPI do
  @moduledoc """
  Client for interacting with the Bluesky API
  """

  require Logger

  @base_url "https://bsky.social/xrpc"

  @doc """
  Fetch a user profile by their DID (Decentralized Identifier)
  """
  def get_profile_by_did(did) when is_binary(did) do
    url = "#{@base_url}/com.atproto.repo.describeRepo?repo=#{URI.encode(did)}"
    
    case Finch.build(:get, url) |> Finch.request(NathanForUs.Finch) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, profile_data} ->
            {:ok, profile_data}
          {:error, reason} ->
            Logger.error("Failed to decode Bluesky profile JSON: #{inspect(reason)}")
            {:error, :decode_error}
        end
      {:ok, %{status: status_code}} ->
        Logger.error("Bluesky API returned status #{status_code} for DID #{did}")
        {:error, {:api_error, status_code}}
      {:error, reason} ->
        Logger.error("Failed to fetch Bluesky profile for DID #{did}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetch a user profile by their handle
  """
  def get_profile_by_handle(handle) when is_binary(handle) do
    url = "#{@base_url}/com.atproto.identity.resolveHandle?handle=#{URI.encode(handle)}"
    
    case Finch.build(:get, url) |> Finch.request(NathanForUs.Finch) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"did" => did}} ->
            get_profile_by_did(did)
          {:ok, _} ->
            {:error, :no_did_found}
          {:error, reason} ->
            Logger.error("Failed to decode handle resolution JSON: #{inspect(reason)}")
            {:error, :decode_error}
        end
      {:ok, %{status: status_code}} ->
        Logger.error("Bluesky API returned status #{status_code} for handle #{handle}")
        {:error, {:api_error, status_code}}
      {:error, reason} ->
        Logger.error("Failed to resolve Bluesky handle #{handle}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract DID from a post's URI
  AT Protocol URIs look like: at://did:plc:abc123def456/app.bsky.feed.post/xyz789
  """
  def extract_did_from_uri(uri) when is_binary(uri) do
    case String.split(uri, "/") do
      ["at:", "", did | _rest] when is_binary(did) ->
        {:ok, did}
      _ ->
        {:error, :invalid_uri}
    end
  end
end