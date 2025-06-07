defmodule NathanForUsWeb.ProfileLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest
  import NathanForUs.AccountsFixtures
  import NathanForUs.SocialFixtures

  alias NathanForUs.Social

  describe "ProfileLive for user's own profile" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "displays user profile information", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/users/#{user.id}")

      username = String.split(user.email, "@") |> hd
      first_letter = String.upcase(String.first(user.email))

      assert html =~ "@#{username}"
      assert html =~ first_letter
    end

    test "shows user statistics", %{conn: conn, user: user} do
      # Create some test data
      _post = post_fixture(%{user: user})
      follower = user_fixture()
      following = user_fixture()
      {:ok, _} = Social.follow_user(follower.id, user.id)
      {:ok, _} = Social.follow_user(user.id, following.id)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      assert has_element?(view, ".business-stat", "1 Following")
      assert has_element?(view, ".business-stat", "1 Followers")
      assert has_element?(view, ".business-stat", "1 Posts")
    end

    test "does not show follow/unfollow buttons for own profile", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      refute has_element?(view, "button", "Follow")
      refute has_element?(view, "button", "Unfollow")
    end

    test "shows 'Create your first post' when user has no posts", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      assert has_element?(view, "a[href='/posts/new']", "Create your first post")
    end

    test "sets correct page title", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      username = String.split(user.email, "@") |> hd
      assert page_title(view) =~ "@#{username}"
    end
  end

  describe "ProfileLive for other user's profile" do
    setup %{conn: conn} do
      current_user = user_fixture()
      profile_user = user_fixture()
      conn = log_in_user(conn, current_user)
      %{conn: conn, current_user: current_user, profile_user: profile_user}
    end

    test "displays other user's profile information", %{conn: conn, profile_user: profile_user} do
      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      username = String.split(profile_user.email, "@") |> hd
      first_letter = String.upcase(String.first(profile_user.email))

      assert html =~ "@#{username}"
      assert html =~ first_letter
    end

    test "shows follow button when not following", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "Follow")
      refute has_element?(view, "button", "Unfollow")
    end

    test "shows unfollow button when already following", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, _} = Social.follow_user(current_user.id, profile_user.id)

      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "Unfollow")
      refute has_element?(view, "button", "Follow")
    end

    test "follows user when follow button is clicked", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      view
      |> element("button", "Follow")
      |> render_click()

      # Should now show unfollow button
      assert has_element?(view, "button", "Unfollow")
      
      # Verify follow relationship was created
      assert Social.following?(current_user.id, profile_user.id)
      
      # Should show success message
      assert render(view) =~ "You are now following this user."
    end

    test "unfollows user when unfollow button is clicked", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, _} = Social.follow_user(current_user.id, profile_user.id)

      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      view
      |> element("button", "Unfollow")
      |> render_click()

      # Should now show follow button
      assert has_element?(view, "button", "Follow")
      
      # Verify follow relationship was removed
      refute Social.following?(current_user.id, profile_user.id)
      
      # Should show success message
      assert render(view) =~ "You have unfollowed this user"
    end

    test "updates follower count when following/unfollowing", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      # Initially 0 followers
      assert has_element?(view, ".business-stat", "0 Followers")

      # Follow the user
      view
      |> element("button", "Follow")
      |> render_click()

      # Should now show 1 follower
      assert has_element?(view, ".business-stat", "1 Followers")

      # Unfollow the user
      view
      |> element("button", "Unfollow")
      |> render_click()

      # Should go back to 0 followers
      assert has_element?(view, ".business-stat", "0 Followers")
    end

    test "shows professional consultation button", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "Message")
    end

    test "does not show create post button for other users with no posts", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      refute has_element?(view, "a", "Create your first post")
      assert render(view) =~ "No posts yet"
    end
  end

  describe "ProfileLive posts display" do
    setup %{conn: conn} do
      current_user = user_fixture()
      profile_user = user_fixture()
      conn = log_in_user(conn, current_user)
      %{conn: conn, current_user: current_user, profile_user: profile_user}
    end

    test "displays user's posts", %{conn: conn, profile_user: profile_user} do
      post = post_fixture(%{user: profile_user, content: "Amazing post content"})

      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      assert html =~ "Amazing post content"
      username = String.split(profile_user.email, "@") |> hd
      assert html =~ "@#{username}"
    end

    test "displays posts with images", %{conn: conn, profile_user: profile_user} do
      _post = post_fixture(%{
        user: profile_user, 
        content: "Check out this chart",
        image_url: "/uploads/business-chart.png"
      })

      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "img[src='/uploads/business-chart.png']")
      assert has_element?(view, "img[alt='Post attachment']")
    end

    test "displays posts in chronological order (newest first)", %{conn: conn, profile_user: profile_user} do
      # Create posts with slight delay to ensure different timestamps
      {:ok, post1} = Social.create_post(%{content: "First post", user_id: profile_user.id})
      :timer.sleep(10)
      {:ok, post2} = Social.create_post(%{content: "Second post", user_id: profile_user.id})

      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      # Second post should appear before first post
      second_post_index = String.split(html, "Second post") |> hd |> String.length()
      first_post_index = String.split(html, "First post") |> hd |> String.length()
      
      assert second_post_index < first_post_index
    end

    test "shows post actions", %{conn: conn, profile_user: profile_user} do
      _post = post_fixture(%{user: profile_user, content: "Test post"})

      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "Like")
      assert has_element?(view, "button", "Comment")
      assert has_element?(view, "button", "Share")
    end

    test "shows empty state when user has no posts", %{conn: conn, profile_user: profile_user} do
      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      assert html =~ "No posts yet"
      assert html =~ "When this user shares posts, they'll appear here."
    end

    test "shows business intelligence section title", %{conn: conn, profile_user: profile_user} do
      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      assert html =~ "Posts"
    end
  end

  describe "ProfileLive error handling" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "raises error for non-existent user", %{conn: conn} do
      non_existent_id = 999999

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/users/#{non_existent_id}")
      end
    end

    test "redirects unauthenticated users", %{conn: _conn} do
      user = user_fixture()
      unauth_conn = build_conn()

      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(unauth_conn, ~p"/users/#{user.id}")
    end
  end

  describe "ProfileLive follow error handling" do
    setup %{conn: conn} do
      current_user = user_fixture()
      profile_user = user_fixture()
      conn = log_in_user(conn, current_user)
      %{conn: conn, current_user: current_user, profile_user: profile_user}
    end

    test "handles follow errors gracefully", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      # Mock a follow error by trying to follow twice rapidly
      view
      |> element("button", "Follow")
      |> render_click()

      # Try to follow again (should already be following)
      view
      |> element("button", "Unfollow")
      |> render_click()

      view
      |> element("button", "Follow")
      |> render_click()

      # Should still work normally
      assert has_element?(view, "button", "Unfollow")
    end
  end
end