defmodule NathanForUs.Admin do
  @moduledoc """
  Administrative functions for managing the application.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo
  alias NathanForUs.Social
  alias NathanForUs.Social.{BlueskyPost, BlueskyUser}

  require Logger

  @doc """
  Backfills Bluesky user profiles for posts that don't have associated users.
  Returns a summary of the operation.
  """
  def backfill_bluesky_profiles(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    dry_run = Keyword.get(opts, :dry_run, false)

    Logger.info("Starting Bluesky profile backfill (limit: #{limit}, dry_run: #{dry_run})")

    # Find posts without associated users
    posts_without_users = 
      from(bp in BlueskyPost,
        left_join: bu in BlueskyUser, on: bp.bluesky_user_id == bu.id,
        where: is_nil(bu.id),
        limit: ^limit,
        select: bp
      )
      |> Repo.all()

    Logger.info("Found #{length(posts_without_users)} posts without user profiles")

    # Extract unique DIDs from posts
    unique_dids = 
      posts_without_users
      |> Enum.map(& &1.did)
      |> Enum.filter(& &1 != nil)
      |> Enum.uniq()

    Logger.info("Found #{length(unique_dids)} unique DIDs to process")

    if dry_run do
      Logger.info("DRY RUN: Would process DIDs: #{inspect(Enum.take(unique_dids, 5))}...")
      {:ok, %{
        posts_found: length(posts_without_users),
        unique_dids: length(unique_dids),
        processed: 0,
        successful: 0,
        failed: 0,
        dry_run: true
      }}
    else
      process_dids(unique_dids, posts_without_users)
    end
  end

  defp process_dids(dids, posts) do
    results = %{
      posts_found: length(posts),
      unique_dids: length(dids),
      processed: 0,
      successful: 0,
      failed: 0,
      dry_run: false
    }

    dids
    |> Enum.with_index()
    |> Enum.reduce(results, fn {did, index}, acc ->
      Logger.info("Processing DID #{index + 1}/#{length(dids)}: #{String.slice(did, 0, 20)}...")
      
      case fetch_and_link_profile(did, posts) do
        {:ok, _user} ->
          Logger.info("Successfully fetched and linked profile for DID: #{String.slice(did, 0, 20)}")
          %{acc | processed: acc.processed + 1, successful: acc.successful + 1}
        
        {:error, reason} ->
          Logger.warning("Failed to fetch profile for DID #{String.slice(did, 0, 20)}: #{inspect(reason)}")
          %{acc | processed: acc.processed + 1, failed: acc.failed + 1}
      end
    end)
  end

  defp fetch_and_link_profile(did, posts) do
    # Check if user already exists
    case Repo.get_by(BlueskyUser, did: did) do
      %BlueskyUser{} = existing_user ->
        # User exists, link posts to this user
        link_posts_to_user(posts, did, existing_user.id)
        {:ok, existing_user}
      
      nil ->
        # User doesn't exist, fetch from API
        case Social.fetch_and_store_bluesky_user(did) do
          {:ok, new_user} ->
            # Link posts to the newly created user
            link_posts_to_user(posts, did, new_user.id)
            {:ok, new_user}
          
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp link_posts_to_user(posts, did, user_id) do
    # Find posts with this DID and update them to reference the user
    posts_to_update = Enum.filter(posts, & &1.did == did)
    
    Enum.each(posts_to_update, fn post ->
      post
      |> Ecto.Changeset.change(bluesky_user_id: user_id)
      |> Repo.update()
    end)
    
    Logger.info("Linked #{length(posts_to_update)} posts to user #{user_id}")
  end

  @doc """
  Gets statistics about posts and users for admin dashboard.
  """
  def get_stats do
    %{
      total_posts: Repo.aggregate(BlueskyPost, :count),
      posts_with_users: from(bp in BlueskyPost, where: not is_nil(bp.bluesky_user_id)) |> Repo.aggregate(:count),
      posts_without_users: from(bp in BlueskyPost, where: is_nil(bp.bluesky_user_id)) |> Repo.aggregate(:count),
      total_users: Repo.aggregate(BlueskyUser, :count),
      unique_dids_in_posts: from(bp in BlueskyPost, where: not is_nil(bp.rkey), distinct: bp.rkey) |> Repo.aggregate(:count)
    }
  end

  @doc """
  Checks if a user is an admin.
  """
  def is_admin?(%{is_admin: true}), do: true
  def is_admin?(_), do: false

  @doc """
  Generates usernames for all users without usernames based on their email.
  Returns the number of users updated.
  """
  def generate_usernames_from_emails do
    alias NathanForUs.Accounts.User
    
    # Find all users without usernames
    users_without_usernames = 
      from(u in User,
        where: is_nil(u.username),
        select: u
      )
      |> Repo.all()

    Logger.info("Found #{length(users_without_usernames)} users without usernames")

    # Generate and update usernames
    updated_count = 
      users_without_usernames
      |> Enum.with_index()
      |> Enum.reduce(0, fn {user, index}, acc ->
        username = generate_username_from_email(user.email)
        
        Logger.info("Updating user #{index + 1}/#{length(users_without_usernames)}: #{user.email} -> #{username}")
        
        case update_user_username(user, username) do
          {:ok, _updated_user} ->
            acc + 1
          {:error, reason} ->
            Logger.warning("Failed to update username for #{user.email}: #{inspect(reason)}")
            acc
        end
      end)

    Logger.info("Successfully updated #{updated_count} usernames")
    updated_count
  end

  defp generate_username_from_email(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.slice(0, 20)
  end

  defp update_user_username(user, username) do
    alias NathanForUs.Accounts.User
    
    user
    |> User.changeset(%{username: username})
    |> Repo.update()
  end
end