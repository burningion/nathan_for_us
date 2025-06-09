defmodule NathanForUs.Social do
  @moduledoc """
  The Social context.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo

  alias NathanForUs.Social.{Post, Follow, BlueskyPost, BlueskyUser}
  alias NathanForUs.BlueskyAPI

  @doc """
  Returns the list of posts for a user's feed (posts from followed users + own posts).
  """
  def list_feed_posts(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    
    following_ids = 
      from(f in Follow, where: f.follower_id == ^user_id, select: f.following_id)
      |> Repo.all()

    user_ids = [user_id | following_ids]

    from(p in Post,
      where: p.user_id in ^user_ids,
      order_by: [desc: p.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of posts for a specific user.
  """
  def list_user_posts(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    
    from(p in Post,
      where: p.user_id == ^user_id,
      order_by: [desc: p.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single post.
  """
  def get_post!(id), do: Repo.get!(Post, id) |> Repo.preload(:user)

  @doc """
  Creates a post.
  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Follows a user.
  """
  def follow_user(follower_id, following_id) do
    %Follow{}
    |> Follow.changeset(%{follower_id: follower_id, following_id: following_id})
    |> Repo.insert()
  end

  @doc """
  Unfollows a user.
  """
  def unfollow_user(follower_id, following_id) do
    from(f in Follow,
      where: f.follower_id == ^follower_id and f.following_id == ^following_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Checks if user1 follows user2.
  """
  def following?(follower_id, following_id) do
    from(f in Follow,
      where: f.follower_id == ^follower_id and f.following_id == ^following_id
    )
    |> Repo.exists?()
  end

  @doc """
  Gets follower count for a user.
  """
  def get_follower_count(user_id) do
    from(f in Follow, where: f.following_id == ^user_id, select: count())
    |> Repo.one()
  end

  @doc """
  Gets following count for a user.
  """
  def get_following_count(user_id) do
    from(f in Follow, where: f.follower_id == ^user_id, select: count())
    |> Repo.one()
  end

  @doc """
  Creates a bluesky post from firehose record data.
  """
  def create_bluesky_post_from_record(record_data) do
    attrs = BlueskyPost.from_firehose_record(record_data)
    
    # Get or create the user if we have a repo (DID)
    attrs_with_user = case record_data["repo"] do
      nil -> attrs
      repo_did ->
        case get_or_create_bluesky_user_by_did(repo_did) do
          {:ok, user} -> Map.put(attrs, :bluesky_user_id, user.id)
          {:error, _reason} -> attrs  # Continue without user if API fails
        end
    end
    
    case %BlueskyPost{}
         |> BlueskyPost.changeset(attrs_with_user)
         |> Repo.insert() do
      {:ok, post} ->
        # Preload the user for the broadcast
        post_with_user = Repo.preload(post, :bluesky_user)
        Phoenix.PubSub.broadcast(NathanForUs.PubSub, "nathan_fielder_skeets", {:new_nathan_fielder_skeet, post_with_user})
        {:ok, post_with_user}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Returns the list of bluesky posts.
  """
  def list_bluesky_posts(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    
    from(bp in BlueskyPost,
      order_by: [desc: bp.record_created_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets a single bluesky post.
  """
  def get_bluesky_post!(id), do: Repo.get!(BlueskyPost, id)

  @doc """
  Gets or creates a BlueskyUser by DID, fetching from API if needed
  """
  def get_or_create_bluesky_user_by_did(did) when is_binary(did) do
    case Repo.get_by(BlueskyUser, did: did) do
      %BlueskyUser{} = user ->
        {:ok, user}
      nil ->
        fetch_and_store_bluesky_user(did)
    end
  end

  @doc """
  Fetches user profile from Bluesky API and stores in database
  """
  def fetch_and_store_bluesky_user(did) when is_binary(did) do
    require Logger
    Logger.info("Fetching Bluesky user profile for DID: #{did}")
    
    case BlueskyAPI.get_profile_by_did(did) do
      {:ok, profile_data} ->
        Logger.info("Successfully fetched profile data for DID #{did}: #{inspect(profile_data)}")
        attrs = BlueskyUser.from_api_profile(profile_data)
        Logger.info("Mapped profile attributes: #{inspect(attrs)}")
        
        %BlueskyUser{}
        |> BlueskyUser.changeset(attrs)
        |> Repo.insert()
      {:error, reason} ->
        Logger.error("Failed to fetch profile for DID #{did}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Returns the list of bluesky posts with preloaded users.
  """
  def list_bluesky_posts_with_users(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    
    # Handles to filter out (test accounts)
    filtered_handles = ["bobbby.online", "yburyug.bsky.social"]
    
    from(bp in BlueskyPost,
      left_join: bu in BlueskyUser, on: bp.bluesky_user_id == bu.id,
      where: is_nil(bu.handle) or bu.handle not in ^filtered_handles,
      order_by: [desc: bp.record_created_at],
      limit: ^limit,
      preload: [:bluesky_user]
    )
    |> Repo.all()
  end
end