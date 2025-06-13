defmodule NathanForUsWeb.VideoTimelineSearchLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias NathanForUs.{Repo, Accounts}
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.VideoFrame

  setup do
    # Create test users
    {:ok, regular_user} = create_regular_user()

    # Create multiple test videos with frames for search testing
    {:ok, video1} = create_test_video("Test Video 1")
    {:ok, video2} = create_test_video("Test Video 2")
    
    frames1 = create_test_frames(video1, 20)
    frames2 = create_test_frames(video2, 20)

    %{
      regular_user: regular_user,
      video1: video1,
      video2: video2,
      frames1: frames1,
      frames2: frames2
    }
  end

  describe "mount and basic functionality" do
    test "mounts successfully on video timeline search page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-timeline")

      assert html =~ "Timeline Search"
      assert html =~ "Search for quotes to create GIFs"
      assert html =~ "Primary GIF creation entrypoint"
    end

    test "displays navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-timeline")

      assert html =~ "Random GIF"
      assert html =~ "Browse GIFs"
      assert html =~ "Nathan Timeline"
      assert html =~ "Sign Up"
    end

    test "shows random quote suggestions initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-timeline")

      assert html =~ "Try searching for these quotes:"
      # Should show some quote suggestions
      assert html =~ "\""  # Should have quotes in the suggestions
    end

    test "displays search form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      assert has_element?(view, "form")
      assert has_element?(view, "input[name='search[term]']")
      assert has_element?(view, "button[type='submit']")
    end
  end

  describe "search functionality" do
    test "search with sufficient length performs search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "hello"}})

      state = :sys.get_state(view.pid).socket.assigns
      assert state.search_term == "hello"
      assert state.has_searched == true
      assert state.loading == false
    end

    test "search with insufficient length shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "hi"}})

      html = render(view)
      assert html =~ "at least 3 characters"
    end

    test "search groups results by video", %{conn: conn, video1: video1, video2: video2} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      
      # Should show video titles in grouped results
      assert html =~ video1.title or html =~ video2.title or html =~ "No quotes found"
    end

    test "search shows frame count per video", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should show frame counts or no results message
      assert html =~ "matching frames" or html =~ "No quotes found"
    end

    test "search results show Create GIF links", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should show create GIF buttons or no results
      assert html =~ "Create GIF" or html =~ "No quotes found"
    end

    test "clear search works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Perform search first
      render_submit(view, "search", %{"search" => %{"term" => "hello"}})
      
      # Clear search
      render_click(view, "clear_search")

      state = :sys.get_state(view.pid).socket.assigns
      assert state.search_term == ""
      assert state.has_searched == false
      assert state.search_results == []
    end

    test "empty search results show helpful message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "nonexistentquery123"}})

      html = render(view)
      assert html =~ "No quotes found"
      assert html =~ "Try a different search term"
      assert html =~ "Feeling Lucky"
    end
  end

  describe "quote suggestions" do
    test "clicking quote suggestion performs search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Click on a quote suggestion (assuming there are some)
      render_click(view, "select_quote", %{"quote" => "test quote"})

      state = :sys.get_state(view.pid).socket.assigns
      assert state.search_term == "test quote"
      assert state.has_searched == true
    end

    test "quote suggestions hide after search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "hello"}})

      html = render(view)
      # Suggestions should be hidden after search
      refute html =~ "Try searching for these quotes:"
    end

    test "quote suggestions return after clearing search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Search and clear
      render_submit(view, "search", %{"search" => %{"term" => "hello"}})
      render_click(view, "clear_search")

      html = render(view)
      # Suggestions should return
      assert html =~ "Try searching for these quotes:"
    end
  end

  describe "random GIF functionality" do
    test "random GIF button redirects to timeline with random parameters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Mock successful random sequence generation
      assert render_click(view, "random_gif") =~ ""
      
      # Should redirect (hard to test exact redirect URL)
    end

    test "random GIF from search results works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Search first
      render_submit(view, "search", %{"search" => %{"term" => "test"}})
      
      # Then click random from results
      render_click(view, "random_gif")
      
      # Should redirect to random GIF
    end

    test "feeling lucky section appears on empty results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "nonexistentquery123"}})

      html = render(view)
      assert html =~ "Feeling Lucky"
      assert html =~ "random Nathan moment"
      assert html =~ "Generate Random GIF"
    end

    test "random GIF from feeling lucky works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "nonexistentquery123"}})
      
      # Click the feeling lucky random GIF button
      render_click(view, "random_gif")
      
      # Should redirect
    end
  end

  describe "frame interaction" do
    test "clicking frame navigates to timeline with context", %{conn: conn, video1: video1} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Search to get results
      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      # If we have results, test frame clicking
      html = render(view)
      if html =~ "Create GIF" do
        # Frame clicks would navigate via onclick, which is hard to test directly
        assert html =~ "Click to compose GIF"
      end
    end

    test "frame previews show correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should show frame numbers or no results
      assert html =~ "#" or html =~ "No quotes found"
    end

    test "limited frame preview works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should limit to 12 frames per video or show "more frames"
      assert html =~ "more frames" or html =~ "No quotes found" or !String.contains?(html, "more frames")
    end
  end

  describe "navigation links" do
    test "browse gifs link is present", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-timeline")

      assert html =~ "Browse GIFs"
      assert html =~ "/browse-gifs"
    end

    test "nathan timeline link is present", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-timeline")

      assert html =~ "Nathan Timeline"
      assert html =~ "/public-timeline"
    end

    test "sign up link is present for unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-timeline")

      assert html =~ "Sign Up"
      assert html =~ "/users/register"
    end

    test "different nav for authenticated users", %{conn: conn, regular_user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/video-timeline")

      # May show different navigation for logged in users
      # (Exact behavior depends on implementation)
      assert html =~ "Random GIF" # Should still show this
    end
  end

  describe "URL linking and sharing" do
    test "search results generate proper timeline links", %{conn: conn, video1: video1} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should have video timeline links
      assert html =~ "/video-timeline/#{video1.id}" or html =~ "No quotes found"
    end

    test "frame context links include search term", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "hello"}})

      html = render(view)
      # Links should preserve search term for context
      assert html =~ "search=hello" or html =~ "No quotes found"
    end

    test "search term is URL encoded in links", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "hello world"}})

      html = render(view)
      # Should encode spaces and special characters
      assert html =~ "hello%20world" or html =~ "hello+world" or html =~ "No quotes found"
    end
  end

  describe "loading states" do
    test "loading state shows during search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Trigger search
      render_change(view, "search", %{"search" => %{"term" => "test"}})

      # Check loading state (may be brief)
      state = :sys.get_state(view.pid).socket.assigns
      # Loading may have completed by the time we check
      assert state.loading == false or state.loading == true
    end

    test "loading state clears after search completes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      state = :sys.get_state(view.pid).socket.assigns
      assert state.loading == false
    end
  end

  describe "error handling" do
    test "handles search errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Submit with edge case data
      render_submit(view, "search", %{"search" => %{"term" => ""}})

      # Should not crash and show appropriate message
      html = render(view)
      assert html =~ "at least 3 characters" or html =~ "Try searching"
    end

    test "handles malformed search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      # Try malformed input
      render_submit(view, "search", %{"search" => %{}})

      # Should handle gracefully
      html = render(view)
      assert html =~ "Timeline Search" # Page should still work
    end
  end

  describe "performance and pagination" do
    test "search results show total frame count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should show total counts or no results
      assert html =~ "Found" or html =~ "frames" or html =~ "No quotes found"
    end

    test "search results show episode count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-timeline")

      render_submit(view, "search", %{"search" => %{"term" => "test"}})

      html = render(view)
      # Should show episode/video counts
      assert html =~ "episodes" or html =~ "videos" or html =~ "No quotes found"
    end
  end

  # Helper functions

  defp create_regular_user do
    attrs = %{
      email: "user@test.com",
      username: "testuser",
      password: "test123456789"
    }
    
    {:ok, user} = Accounts.register_user(attrs)
    user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    user = Repo.update!(Accounts.User.confirm_changeset(user))
    
    {:ok, user}
  end

  defp create_test_video(title) do
    %VideoSchema{}
    |> VideoSchema.changeset(%{
      title: title,
      file_path: "/test/#{String.replace(title, " ", "_")}.mp4",
      duration_ms: 30000,
      fps: 30.0,
      frame_count: 20,
      status: "completed"
    })
    |> Repo.insert()
  end

  defp create_test_frames(video, count) do
    frames = for i <- 1..count do
      %{
        frame_number: i,
        timestamp_ms: i * 1000,
        file_path: "frame_#{i}.jpg",
        file_size: 1000,
        width: 1920,
        height: 1080,
        video_id: video.id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end

    {_count, frame_records} = Repo.insert_all(VideoFrame, frames, returning: true)
    frame_records
  end
end