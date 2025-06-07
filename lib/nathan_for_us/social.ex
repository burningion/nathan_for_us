defmodule NathanForUs.Social do
  @moduledoc """
  The Social context.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo

  alias NathanForUs.Social.Post
  alias NathanForUs.Social.Follow
  alias NathanForUs.Accounts.User

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
end