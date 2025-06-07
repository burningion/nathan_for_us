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
      assert html =~ "Certified Business Understander"
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

      assert has_element?(view, ".business-stat", "1 Strategic Partnerships")
      assert has_element?(view, ".business-stat", "1 Professional Followers")
      assert has_element?(view, ".business-stat", "1 Business Insights")
    end

    test "does not show follow/unfollow buttons for own profile", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      refute has_element?(view, "button", "Form Strategic Partnership")
      refute has_element?(view, "button", "End Partnership")
    end

    test "shows 'Share Your First Business Insight' when user has no posts", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      assert has_element?(view, "a[href='/posts/new']", "Share Your First Business Insight")
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
      assert html =~ "Certified Business Understander"
      assert html =~ first_letter
    end

    test "shows follow button when not following", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "Form Strategic Partnership")
      refute has_element?(view, "button", "End Partnership")
    end

    test "shows unfollow button when already following", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, _} = Social.follow_user(current_user.id, profile_user.id)

      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "End Partnership")
      refute has_element?(view, "button", "Form Strategic Partnership")
    end

    test "follows user when follow button is clicked", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      view
      |> element("button", "Form Strategic Partnership")
      |> render_click()

      # Should now show unfollow button
      assert has_element?(view, "button", "End Partnership")
      
      # Verify follow relationship was created
      assert Social.following?(current_user.id, profile_user.id)
      
      # Should show success message
      assert render(view) =~ "You are now following this business professional!"
    end

    test "unfollows user when unfollow button is clicked", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, _} = Social.follow_user(current_user.id, profile_user.id)

      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      view
      |> element("button", "End Partnership")
      |> render_click()

      # Should now show follow button
      assert has_element?(view, "button", "Form Strategic Partnership")
      
      # Verify follow relationship was removed
      refute Social.following?(current_user.id, profile_user.id)
      
      # Should show success message
      assert render(view) =~ "You have unfollowed this user"
    end

    test "updates follower count when following/unfollowing", %{conn: conn, current_user: current_user, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      # Initially 0 followers
      assert has_element?(view, ".business-stat", "0 Professional Followers")

      # Follow the user
      view
      |> element("button", "Form Strategic Partnership")
      |> render_click()

      # Should now show 1 follower
      assert has_element?(view, ".business-stat", "1 Professional Followers")

      # Unfollow the user
      view
      |> element("button", "End Partnership")
      |> render_click()

      # Should go back to 0 followers
      assert has_element?(view, ".business-stat", "0 Professional Followers")
    end

    test "shows professional consultation button", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      assert has_element?(view, "button", "Professional Consultation")
    end

    test "does not show create post button for other users with no posts", %{conn: conn, profile_user: profile_user} do
      {:ok, view, _html} = live(conn, ~p"/users/#{profile_user.id}")

      refute has_element?(view, "a", "Share Your First Business Insight")
      assert render(view) =~ "No business insights published yet!"
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
      post = post_fixture(%{user: profile_user, content: "Amazing business strategy"})

      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      assert html =~ "Amazing business strategy"
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
      assert has_element?(view, "img[alt='Business insight visualization']")
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

      assert has_element?(view, "button", "Professional Endorsement")
      assert has_element?(view, "button", "Business Excellence")
      assert has_element?(view, "button", "Strategic Value")
      assert has_element?(view, "button", "Revenue Opportunity")
    end

    test "shows empty state when user has no posts", %{conn: conn, profile_user: profile_user} do
      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      assert html =~ "No business insights published yet!"
      assert html =~ "This business professional is currently developing revolutionary strategies"
    end

    test "shows business intelligence section title", %{conn: conn, profile_user: profile_user} do
      {:ok, _view, html} = live(conn, ~p"/users/#{profile_user.id}")

      assert html =~ "Business Intelligence & Strategic Insights"
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
      |> element("button", "Form Strategic Partnership")
      |> render_click()

      # Try to follow again (should already be following)
      view
      |> element("button", "End Partnership")
      |> render_click()

      view
      |> element("button", "Form Strategic Partnership")
      |> render_click()

      # Should still work normally
      assert has_element?(view, "button", "End Partnership")
    end
  end
end