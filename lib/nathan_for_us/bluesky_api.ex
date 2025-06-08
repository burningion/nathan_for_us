defmodule NathanForUs.BlueskyAPI do
  @moduledoc """
  Client for interacting with the Bluesky API
  """

  require Logger

  @base_url "https://bsky.social/xrpc"

  defp get_access_token do
    username = System.get_env("BLUESKY_USERNAME")
    password = System.get_env("BLUESKY_APP_PASSWORD")
    
    if username && password do
      case create_session(username, password) do
        {:ok, access_token} -> access_token
        {:error, _} -> nil
      end
    else
      nil
    end
  end

  defp create_session(username, password) do
    url = "#{@base_url}/com.atproto.server.createSession"
    body = Jason.encode!(%{identifier: username, password: password})
    headers = [{"Content-Type", "application/json"}]
    
    Logger.info("Creating Bluesky session for user: #{username}")
    
    case Finch.build(:post, url, headers, body) |> Finch.request(NathanForUs.Finch) do
      {:ok, %{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"accessJwt" => access_token}} -> 
            Logger.info("Successfully created Bluesky session")
            {:ok, access_token}
          {:error, reason} -> 
            Logger.error("Failed to decode session response: #{inspect(reason)}")
            {:error, reason}
        end
      {:ok, %{status: status_code, body: error_body}} ->
        Logger.error("Bluesky session creation failed with status #{status_code}: #{error_body}")
        {:error, {:auth_error, status_code}}
      {:error, reason} ->
        Logger.error("Network error creating Bluesky session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetch a user profile by their DID (Decentralized Identifier)
  """
  def get_profile_by_did(did) when is_binary(did) do
    case get_access_token() do
      nil ->
        Logger.error("Failed to get Bluesky access token")
        {:error, :auth_failed}
      access_token ->
        url = "#{@base_url}/app.bsky.actor.getProfile?actor=#{URI.encode(did)}"
        headers = [{"Authorization", "Bearer #{access_token}"}]
        
        case Finch.build(:get, url, headers) |> Finch.request(NathanForUs.Finch) do
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