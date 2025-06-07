defmodule NathanForUsWeb.PostLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest
  import NathanForUs.AccountsFixtures

  alias NathanForUs.Social

  describe "PostLive" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "displays post creation form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/posts/new")

      assert html =~ "Create Post"
    end

    test "shows correct page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      assert page_title(view) =~ "Create Post"
    end

    test "has content textarea field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      assert has_element?(view, "textarea[name='post[content]']")
      assert has_element?(view, "textarea[placeholder*='mind']")
    end

    test "has image upload field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      assert has_element?(view, "input[type='file']")
      assert has_element?(view, "button", "Choose File")
    end

    test "has submit and cancel buttons", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      assert has_element?(view, "button[type='submit']", "Post")
      assert has_element?(view, "a[href='/']", "Cancel")
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Send empty form data to trigger validation
      view
      |> form("#post-form", post: %{content: ""})
      |> render_change()

      # Form should still be present (no redirect on validation)
      assert has_element?(view, "form")
    end

    test "creates post with valid content", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      view
      |> form("form", post: %{content: "Revolutionary business strategy"})
      |> render_submit()

      # Should redirect to feed
      assert_redirect(view, ~p"/")

      # Verify post was created
      posts = Social.list_user_posts(user.id)
      assert length(posts) == 1
      assert hd(posts).content == "Revolutionary business strategy"
    end

    test "shows flash message on successful post creation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      view
      |> form("form", post: %{content: "Test strategy"})
      |> render_submit()

      flash = assert_redirect(view, ~p"/")
      assert flash["info"] =~ "Post created successfully"
    end

    test "displays validation errors for invalid post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Submit empty form (should be invalid)
      html = view
      |> form("form", post: %{content: ""})
      |> render_submit()

      # Should stay on form page and show error
      assert html =~ "must have either content or image"
    end

    test "disables submit button when form is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Change to invalid data
      html = view
      |> form("form", post: %{content: ""})
      |> render_change()

      # Submit button should be disabled  
      assert html =~ "disabled"
    end

    test "enables submit button when form is valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Change to valid data
      html = view
      |> form("form", post: %{content: "Valid business content"})
      |> render_change()

      # Submit button should not be disabled
      refute html =~ "disabled"
    end

    test "handles file upload selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Simulate file selection
      upload = file_input(view, "form", :image, [
        %{
          last_modified: 1_594_171_879_000,
          name: "business-chart.png",
          content: "fake image content",
          size: 1_396,
          type: "image/png"
        }
      ])

      render_upload(upload, "business-chart.png")

      # Should show uploaded file
      assert render(view) =~ "business-chart.png"
    end

    test "allows canceling file upload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Simulate file selection
      upload = file_input(view, "form", :image, [
        %{
          last_modified: 1_594_171_879_000,
          name: "business-chart.png",
          content: "fake image content",
          size: 1_396,
          type: "image/png"
        }
      ])

      render_upload(upload, "business-chart.png")

      # Cancel the upload
      view
      |> element("button", "Remove")
      |> render_click()

      # File should be removed
      refute render(view) =~ "business-chart.png"
    end

    test "creates post with image only (no content)", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Upload a file
      upload = file_input(view, "form", :image, [
        %{
          last_modified: 1_594_171_879_000,
          name: "chart.png",
          content: "fake image content",
          size: 1_396,
          type: "image/png"
        }
      ])

      render_upload(upload, "chart.png")

      # Submit form with no content but with image
      view
      |> form("form", post: %{content: ""})
      |> render_submit()

      # Should redirect successfully
      assert_redirect(view, ~p"/")

      # Verify post was created with image
      posts = Social.list_user_posts(user.id)
      assert length(posts) == 1
      post = hd(posts)
      assert post.image_url != nil
      assert post.content == nil || post.content == ""
    end

    test "broadcasts post creation via PubSub", %{conn: conn, user: user} do
      # Subscribe to the posts topic
      Phoenix.PubSub.subscribe(NathanForUs.PubSub, "posts")

      {:ok, view, _html} = live(conn, ~p"/posts/new")

      view
      |> form("form", post: %{content: "PubSub test post"})
      |> render_submit()

      # Should receive PubSub message
      assert_receive {:post_created, post}
      assert post.content == "PubSub test post"
      assert post.user_id == user.id
    end

    test "redirects unauthenticated users", %{conn: _conn} do
      # Create a new connection without authentication
      unauth_conn = build_conn()

      # Should redirect to login
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(unauth_conn, ~p"/posts/new")
    end

    test "handles form validation errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Submit form with content that will cause validation error
      html = view
      |> form("form", post: %{content: nil})
      |> render_submit()

      # Should stay on form and show validation message
      assert html =~ "Create Post"
      assert html =~ "must have either content or image"
    end

    test "handles very long content", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      long_content = String.duplicate("a", 5000)

      view
      |> form("form", post: %{content: long_content})
      |> render_submit()

      # Should create post successfully
      assert_redirect(view, ~p"/")

      posts = Social.list_user_posts(user.id)
      assert length(posts) == 1
      assert hd(posts).content == long_content
    end
  end
end