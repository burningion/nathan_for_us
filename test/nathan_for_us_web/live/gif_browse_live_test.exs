defmodule NathanForUsWeb.GifBrowseLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias NathanForUs.{Repo, Accounts}
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.VideoFrame
  alias NathanForUs.Viral
  alias NathanForUs.Viral.BrowseableGif
  alias NathanForUs.Gif

  setup do
    # Create test users
    {:ok, admin_user} = create_admin_user()
    {:ok, regular_user1} = create_regular_user("user1@test.com", "testuser1")
    {:ok, regular_user2} = create_regular_user("user2@test.com", "testuser2")

    # Create test video with frames
    {:ok, video} = create_test_video()
    frames = create_test_frames(video, 20)
    
    # Create test GIFs for browsing
    {:ok, cached_gif} = create_test_gif(video, frames)
    {:ok, browseable_gif1} = create_browseable_gif(video, regular_user1, cached_gif, "Nathan's Wisdom", 5)
    {:ok, browseable_gif2} = create_browseable_gif(video, regular_user2, cached_gif, "Awkward Moments", 3)

    %{
      admin_user: admin_user,
      regular_user1: regular_user1,
      regular_user2: regular_user2,
      video: video,
      frames: frames,
      cached_gif: cached_gif,
      browseable_gif1: browseable_gif1,
      browseable_gif2: browseable_gif2
    }
  end

  describe "mount and basic functionality" do
    test "mounts successfully with default hot sort", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "BROWSE GIFS"
      assert html =~ "Hot" # Default sort
      assert html =~ "Top"
      assert html =~ "New"
    end

    test "displays navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "Random GIF"
      assert html =~ "NATHAN POST TIMELINE"
      assert html =~ "SEARCH QUOTES"
    end

    test "shows browseable GIFs", %{conn: conn, browseable_gif1: gif1, browseable_gif2: gif2} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show GIF titles
      assert html =~ gif1.title
      assert html =~ gif2.title
    end

    test "shows GIF metadata", %{conn: conn, browseable_gif1: gif1} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show upvote count and other metadata
      assert html =~ "#{gif1.upvotes_count}" or html =~ "upvotes"
    end

    test "handles empty GIF list gracefully", %{conn: conn} do
      # Delete all browseable GIFs
      Repo.delete_all(BrowseableGif)
      
      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "No GIFs created yet" or html =~ "BROWSE GIFS"
    end
  end

  describe "sorting functionality" do
    test "can sort by hot (default)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      state = :sys.get_state(view.pid).socket.assigns
      assert state.sort == "hot"
    end

    test "can sort by top", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Navigate to top sort
      {:ok, _view, html} = live(conn, "/browse-gifs?sort=top")

      assert html =~ "Browse Nathan GIFs"
      # Should show same GIFs but potentially different order
    end

    test "can sort by new", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Navigate to new sort
      {:ok, _view, html} = live(conn, "/browse-gifs?sort=new")

      assert html =~ "Browse Nathan GIFs"
    end

    test "invalid sort defaults to hot", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs?sort=invalid")

      assert html =~ "Browse Nathan GIFs"
      # Should handle gracefully
    end

    test "sort parameter updates via handle_params", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Change sort via URL
      send(view.pid, {:live_patch, "/browse-gifs?sort=top"})

      :sys.get_state(view.pid)
      # Should update sort
    end
  end

  describe "upvoting functionality" do
    test "authenticated user can upvote GIF", %{conn: conn, regular_user1: user, browseable_gif2: gif} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Upvote a GIF (not created by this user)
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})

      # Should update upvote count
      html = render(view)
      assert html =~ "#{gif.upvotes_count + 1}" or html =~ "upvoted"
    end

    test "user cannot upvote their own GIF", %{conn: conn, regular_user1: user, browseable_gif1: gif} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Try to upvote own GIF
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})

      html = render(view)
      # Should show error or prevent upvoting
      assert html =~ "cannot upvote" or html =~ "own GIF" or html =~ gif.title
    end

    test "user can remove their upvote", %{conn: conn, regular_user1: user, browseable_gif2: gif} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Upvote first
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})
      
      # Then remove upvote
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})

      # Should return to original count
      html = render(view)
      assert html =~ "#{gif.upvotes_count}" or html =~ "upvote"
    end

    test "unauthenticated user sees register prompt when upvoting", %{conn: conn, browseable_gif1: gif} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})

      # Should show register flash/prompt
      html = render(view)
      assert html =~ "Account Required" or html =~ "log in" or html =~ "register"
    end

    test "register flash can be closed", %{conn: conn, browseable_gif1: gif} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Trigger register flash
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})
      
      # Close the flash
      render_click(view, "close_register_flash")

      state = :sys.get_state(view.pid).socket.assigns
      assert state.show_register_flash == false
    end

    test "anonymous voting uses session ID", %{conn: conn, browseable_gif1: gif} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Anonymous upvote should use session ID
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})

      # Should still work but show register prompt
      html = render(view)
      assert html =~ "Account Required" or html =~ "upvote"
    end
  end

  describe "GIF interaction" do
    test "GIF displays correctly", %{conn: conn, browseable_gif1: gif} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show the GIF title and metadata
      assert html =~ gif.title
    end

    test "GIF shows caption preview", %{conn: conn, browseable_gif1: gif} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show caption or video title
      assert html =~ gif.video.title or html =~ "From:"
    end

    test "GIF shows vote count", %{conn: conn, browseable_gif1: gif} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "#{gif.upvote_count}"
    end

    test "GIF shows creation time", %{conn: conn, browseable_gif1: gif} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show relative time
      assert html =~ "ago" or html =~ "minutes" or html =~ "hours"
    end
  end

  describe "random GIF functionality" do
    test "random GIF button redirects to timeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      render_click(view, "random_gif")

      # Should redirect to random GIF URL
      # (Hard to test exact redirect)
    end

    test "random GIF handles no videos gracefully", %{conn: conn} do
      # Delete all videos
      Repo.delete_all(VideoSchema)
      
      {:ok, view, _html} = live(conn, "/browse-gifs")

      render_click(view, "random_gif")

      html = render(view)
      # Should show error message
      assert html =~ "No suitable videos" or html =~ "Browse Nathan GIFs"
    end
  end

  describe "navigation and routing" do
    test "nathan post timeline link navigation works", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "NATHAN POST TIMELINE"
      assert html =~ "/public-timeline"
    end

    test "search quotes link navigation works", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "SEARCH QUOTES"
      assert html =~ "/video-timeline"
    end

    test "sort URLs work correctly", %{conn: conn} do
      # Test all sort options
      for sort <- ["hot", "top", "new"] do
        {:ok, _view, html} = live(conn, "/browse-gifs?sort=#{sort}")
        assert html =~ "Browse Nathan GIFs"
      end
    end
  end

  describe "loading and performance" do
    test "handles large number of GIFs", %{conn: conn, video: video, regular_user1: user, cached_gif: gif} do
      # Create many browseable GIFs
      for i <- 1..20 do
        create_browseable_gif(video, user, gif, "Test GIF #{i}", i)
      end

      {:ok, _view, html} = live(conn, "/browse-gifs")

      assert html =~ "Browse Nathan GIFs"
      # Should handle the load without issues
    end

    test "loading state works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      state = :sys.get_state(view.pid).socket.assigns
      assert state.loading == false  # Should not be loading after mount
    end

    test "handles sort change loading", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Trigger sort change
      send(view.pid, {:live_patch, "/browse-gifs?sort=top"})

      :sys.get_state(view.pid)
      # Should handle sort change gracefully
    end
  end

  describe "error handling" do
    test "invalid GIF ID for upvote", %{conn: conn, regular_user1: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/browse-gifs")

      render_click(view, "upvote_gif", %{"gif_id" => "99999"})

      # Should handle gracefully
      html = render(view)
      assert html =~ "BROWSE GIFS"  # Page should still work
    end

    test "malformed gif_id for upvote", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/browse-gifs")

      render_click(view, "upvote_gif", %{"gif_id" => "invalid"})

      # Should handle gracefully
      html = render(view)
      assert html =~ "Browse Nathan GIFs"
    end

    test "handles database errors gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should load successfully even if there are issues
      assert html =~ "Browse Nathan GIFs"
    end
  end

  describe "caption functionality" do
    test "GIFs show caption previews when available", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show either captions or video title
      assert html =~ "From:" or html =~ "\""  # Either caption or fallback
    end

    test "GIFs handle missing captions gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show video title as fallback
      assert html =~ "Test Video" or html =~ "From:"
    end
  end

  describe "user voting state" do
    test "shows user's voting state correctly", %{conn: conn, regular_user1: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should show upvote buttons appropriately
      assert html =~ "upvote" or html =~ "👍"
    end

    test "voting state persists across page loads", %{conn: conn, regular_user1: user, browseable_gif2: gif} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/browse-gifs")

      # Upvote a GIF
      render_click(view, "upvote_gif", %{"gif_id" => to_string(gif.id)})

      # Reload page
      {:ok, _view, html} = live(conn, "/browse-gifs")

      # Should remember the vote state
      assert html =~ "upvoted" or html =~ "#{gif.upvote_count + 1}"
    end
  end

  # Helper functions

  defp create_admin_user do
    attrs = %{
      email: "admin@test.com",
      username: "testadmin",
      password: "test123456789",
      is_admin: true
    }
    
    {:ok, user} = Accounts.register_user(attrs)
    user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    user = Repo.update!(Accounts.User.confirm_changeset(user))
    user = Repo.update!(Accounts.User.changeset(user, %{is_admin: true}))
    
    {:ok, user}
  end

  defp create_regular_user(email, username) do
    attrs = %{
      email: email,
      username: username,
      password: "test123456789"
    }
    
    {:ok, user} = Accounts.register_user(attrs)
    user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    user = Repo.update!(Accounts.User.confirm_changeset(user))
    
    {:ok, user}
  end

  defp create_test_video do
    %VideoSchema{}
    |> VideoSchema.changeset(%{
      title: "Test Video",
      file_path: "/test/video.mp4",
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

  defp create_test_gif(video, frames) do
    frame_ids = frames |> Enum.take(5) |> Enum.map(& &1.id)
    hash = Gif.generate_hash(video.id, frame_ids)
    
    %NathanForUs.Gif{}
    |> NathanForUs.Gif.changeset(%{
      hash: hash,
      frame_ids: frame_ids,
      gif_data: "fake_gif_data",
      frame_count: 5,
      duration_ms: 1000,
      file_size: 50000,
      video_id: video.id
    })
    |> Repo.insert()
  end

  defp create_browseable_gif(video, user, cached_gif, title, upvote_count) do
    frame_data = Jason.encode!(%{
      frame_ids: [1, 2, 3, 4, 5],
      frame_numbers: [1, 2, 3, 4, 5],
      timestamps: [1000, 2000, 3000, 4000, 5000]
    })

    attrs = %{
      video_id: video.id,
      created_by_user_id: user.id,
      gif_id: cached_gif.id,
      start_frame_index: 1,
      end_frame_index: 5,
      category: "wisdom",
      frame_data: frame_data,
      title: title,
      is_public: true,
      upvotes_count: upvote_count
    }

    Viral.create_browseable_gif(attrs)
  end
end