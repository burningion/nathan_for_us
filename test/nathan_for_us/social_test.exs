defmodule NathanForUs.SocialTest do
  use NathanForUs.DataCase

  alias NathanForUs.Social
  alias NathanForUs.Social.{Post, Follow}

  import NathanForUs.AccountsFixtures
  import NathanForUs.SocialFixtures

  describe "posts" do
    test "list_feed_posts/2 returns posts from followed users and own posts" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      # User1 follows User2
      {:ok, _follow} = Social.follow_user(user1.id, user2.id)

      # Create posts
      post1 = post_fixture(%{user: user1, content: "User1's post"})
      post2 = post_fixture(%{user: user2, content: "User2's post"})
      _post3 = post_fixture(%{user: user3, content: "User3's post"})

      # User1's feed should include their own post and User2's post
      feed_posts = Social.list_feed_posts(user1.id)
      post_ids = Enum.map(feed_posts, & &1.id)

      assert length(feed_posts) == 2
      assert post1.id in post_ids
      assert post2.id in post_ids
    end

    test "list_feed_posts/2 with limit option" do
      user = user_fixture()
      
      # Create 3 posts
      Enum.each(1..3, fn i -> 
        post_fixture(%{user: user, content: "Post #{i}"})
      end)

      feed_posts = Social.list_feed_posts(user.id, limit: 2)
      assert length(feed_posts) == 2
    end

    test "list_user_posts/2 returns only posts for specific user" do
      user1 = user_fixture()
      user2 = user_fixture()

      post1 = post_fixture(%{user: user1, content: "User1's post"})
      _post2 = post_fixture(%{user: user2, content: "User2's post"})

      user_posts = Social.list_user_posts(user1.id)
      assert length(user_posts) == 1
      assert hd(user_posts).id == post1.id
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      retrieved_post = Social.get_post!(post.id)
      assert retrieved_post.id == post.id
      assert retrieved_post.user.id == post.user.id
    end

    test "create_post/1 with valid data creates a post" do
      user = user_fixture()
      valid_attrs = %{content: "Great business strategy", user_id: user.id}

      assert {:ok, %Post{} = post} = Social.create_post(valid_attrs)
      assert post.content == "Great business strategy"
      assert post.user_id == user.id
    end

    test "create_post/1 with image_url creates a post" do
      user = user_fixture()
      valid_attrs = %{
        content: "Check out this graph", 
        image_url: "/uploads/chart.png",
        user_id: user.id
      }

      assert {:ok, %Post{} = post} = Social.create_post(valid_attrs)
      assert post.image_url == "/uploads/chart.png"
    end

    test "create_post/1 with only image_url (no content) creates a post" do
      user = user_fixture()
      valid_attrs = %{image_url: "/uploads/chart.png", user_id: user.id}

      assert {:ok, %Post{} = post} = Social.create_post(valid_attrs)
      assert post.image_url == "/uploads/chart.png"
      assert is_nil(post.content)
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Social.create_post(%{})
    end

    test "create_post/1 without content or image returns error" do
      user = user_fixture()
      invalid_attrs = %{user_id: user.id}

      assert {:error, %Ecto.Changeset{} = changeset} = Social.create_post(invalid_attrs)
      assert %{content: ["must have either content or image"]} = errors_on(changeset)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{content: "Updated business strategy"}

      assert {:ok, %Post{} = updated_post} = Social.update_post(post, update_attrs)
      assert updated_post.content == "Updated business strategy"
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Social.update_post(post, %{content: nil, image_url: nil})
      assert post == Social.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Social.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Social.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Social.change_post(post)
    end
  end

  describe "follows" do
    test "follow_user/2 creates a follow relationship" do
      follower = user_fixture()
      following = user_fixture()

      assert {:ok, %Follow{} = follow} = Social.follow_user(follower.id, following.id)
      assert follow.follower_id == follower.id
      assert follow.following_id == following.id
    end

    test "follow_user/2 prevents duplicate follows" do
      follower = user_fixture()
      following = user_fixture()

      assert {:ok, %Follow{}} = Social.follow_user(follower.id, following.id)
      assert {:error, %Ecto.Changeset{}} = Social.follow_user(follower.id, following.id)
    end

    test "follow_user/2 prevents self-following" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Social.follow_user(user.id, user.id)
      assert %{following_id: ["cannot follow yourself"]} = errors_on(changeset)
    end

    test "unfollow_user/2 removes follow relationship" do
      follower = user_fixture()
      following = user_fixture()

      {:ok, _follow} = Social.follow_user(follower.id, following.id)
      assert Social.following?(follower.id, following.id)

      {1, nil} = Social.unfollow_user(follower.id, following.id)
      refute Social.following?(follower.id, following.id)
    end

    test "following?/2 returns true when user follows another" do
      follower = user_fixture()
      following = user_fixture()

      refute Social.following?(follower.id, following.id)

      {:ok, _follow} = Social.follow_user(follower.id, following.id)
      assert Social.following?(follower.id, following.id)
    end

    test "get_follower_count/1 returns correct count" do
      user = user_fixture()
      follower1 = user_fixture()
      follower2 = user_fixture()

      assert Social.get_follower_count(user.id) == 0

      {:ok, _} = Social.follow_user(follower1.id, user.id)
      assert Social.get_follower_count(user.id) == 1

      {:ok, _} = Social.follow_user(follower2.id, user.id)
      assert Social.get_follower_count(user.id) == 2
    end

    test "get_following_count/1 returns correct count" do
      user = user_fixture()
      following1 = user_fixture()
      following2 = user_fixture()

      assert Social.get_following_count(user.id) == 0

      {:ok, _} = Social.follow_user(user.id, following1.id)
      assert Social.get_following_count(user.id) == 1

      {:ok, _} = Social.follow_user(user.id, following2.id)
      assert Social.get_following_count(user.id) == 2
    end
  end
end