defmodule NathanForUsWeb.FeedLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest
  import NathanForUs.AccountsFixtures
  import NathanForUs.SocialFixtures

  alias NathanForUs.Social

  describe "FeedLive for unauthenticated users" do
    test "displays welcome message and sign up options", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Welcome to The Business Understander"
      assert html =~ "Join the Business Elite"
      assert html =~ "Access Your Account"
      assert html =~ "The most exclusive social network"
    end

    test "shows login and register links", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='/users/log_in']")
      assert has_element?(view, "a[href='/users/register']")
    end

    test "does not show authenticated user features", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      refute html =~ "Share Your Business Wisdom"
      refute html =~ "My Profile"
      refute html =~ "Exit"
    end
  end

  describe "FeedLive for authenticated users" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "displays the business hero section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "The Business Understander"
      assert html =~ "I graduated from one of Canada's top business schools"
      assert html =~ "Where serious professionals share revolutionary business strategies"
    end

    test "shows authenticated user navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='/posts/new']", "Share Wisdom")
      assert has_element?(view, "a", "My Profile")
      assert has_element?(view, "a", "Exit")
    end

    test "shows share wisdom button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='/posts/new']", "Share Your Business Wisdom")
    end

    test "displays empty state when no posts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "No business insights yet!"
      assert html =~ "Follow other business professionals"
    end

    test "displays user's own posts", %{conn: conn, user: user} do
      post = post_fixture(%{user: user, content: "My brilliant business strategy"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "My brilliant business strategy"
      assert html =~ "@#{String.split(user.email, "@") |> hd}"
    end

    test "displays posts from followed users", %{conn: conn, user: user} do
      followed_user = user_fixture()
      {:ok, _follow} = Social.follow_user(user.id, followed_user.id)
      
      post = post_fixture(%{user: followed_user, content: "Followed user's strategy"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Followed user's strategy"
      assert html =~ "@#{String.split(followed_user.email, "@") |> hd}"
    end

    test "does not display posts from non-followed users", %{conn: conn} do
      other_user = user_fixture()
      _post = post_fixture(%{user: other_user, content: "Other user's strategy"})

      {:ok, _view, html} = live(conn, ~p"/")

      refute html =~ "Other user's strategy"
    end

    test "displays posts with images", %{conn: conn, user: user} do
      post = post_fixture(%{
        user: user, 
        content: "Check out this chart",
        image_url: "/uploads/chart.png"
      })

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "img[src='/uploads/chart.png']")
      assert has_element?(view, "img[alt='Business insight visualization']")
    end

    test "displays post actions", %{conn: conn, user: user} do
      _post = post_fixture(%{user: user, content: "Test post"})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "button", "Professional Endorsement")
      assert has_element?(view, "button", "Business Excellence")
      assert has_element?(view, "button", "Strategic Partnership")
      assert has_element?(view, "button", "Revenue Potential")
    end

    test "displays posts in chronological order (newest first)", %{conn: conn, user: user} do
      # Create posts with different timestamps
      {:ok, post1} = Social.create_post(%{content: "First post", user_id: user.id})
      :timer.sleep(10) # Ensure different timestamps
      {:ok, post2} = Social.create_post(%{content: "Second post", user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/")

      # Second post should appear before first post in HTML
      second_post_index = String.split(html, "Second post") |> hd |> String.length()
      first_post_index = String.split(html, "First post") |> hd |> String.length()
      
      assert second_post_index < first_post_index
    end

    test "shows user avatars with first letter of email", %{conn: conn, user: user} do
      _post = post_fixture(%{user: user, content: "Test post"})

      {:ok, view, _html} = live(conn, ~p"/")

      first_letter = String.upcase(String.first(user.email))
      assert has_element?(view, ".business-avatar", first_letter)
    end

    test "shows links to user profiles", %{conn: conn, user: user} do
      _post = post_fixture(%{user: user, content: "Test post"})

      {:ok, view, _html} = live(conn, ~p"/")

      username = String.split(user.email, "@") |> hd
      assert has_element?(view, "a[href='/users/#{user.id}']", "@#{username}")
    end
  end

  describe "FeedLive real-time updates" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "receives new posts via PubSub", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Create a new post and broadcast it
      {:ok, new_post} = Social.create_post(%{content: "New real-time post", user_id: user.id})
      new_post = NathanForUs.Repo.preload(new_post, :user)
      
      send(view.pid, {:post_created, new_post})

      assert render(view) =~ "New real-time post"
    end
  end

  describe "FeedLive page title" do
    test "sets correct page title", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      assert page_title(view) =~ "The Business Understander"
    end
  end
end