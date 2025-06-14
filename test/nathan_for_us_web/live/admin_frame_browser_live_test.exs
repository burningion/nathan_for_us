defmodule NathanForUsWeb.AdminFrameBrowserLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias NathanForUs.{Repo, Accounts}
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.VideoFrame

  setup do
    # Create admin user
    admin_attrs = %{
      email: "admin@test.com",
      username: "testadmin",
      password: "test123456789",
      is_admin: true
    }

    {:ok, admin_user} = Accounts.register_user(admin_attrs)
    admin_user = %{admin_user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    admin_user = Repo.update!(Accounts.User.confirm_changeset(admin_user))

    # Update admin status
    admin_user = Repo.update!(Accounts.User.changeset(admin_user, %{is_admin: true}))

    # Create regular user
    user_attrs = %{
      email: "user@test.com",
      username: "testuser",
      password: "test123456789",
      is_admin: false
    }

    {:ok, regular_user} = Accounts.register_user(user_attrs)

    regular_user = %{
      regular_user
      | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    regular_user = Repo.update!(Accounts.User.confirm_changeset(regular_user))

    # Create test video
    {:ok, video} =
      %VideoSchema{}
      |> VideoSchema.changeset(%{
        title: "Test Video",
        file_path: "/test/video.mp4",
        duration_ms: 10000,
        fps: 30.0,
        frame_count: 10,
        status: "completed"
      })
      |> Repo.insert()

    # Create test frames
    frames =
      for i <- 1..10 do
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

    %{admin_user: admin_user, regular_user: regular_user, video: video, frames: frame_records}
  end

  describe "admin access" do
    test "admin user can access admin frame browser", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/frames")

      assert html =~ "Admin Frame Browser"
      assert html =~ "Browse all frames in a video and create GIFs"
    end

    test "regular user cannot access admin frame browser", %{
      conn: conn,
      regular_user: regular_user
    } do
      conn = log_in_user(conn, regular_user)

      # Should redirect with error
      assert {:error,
              {:redirect,
               %{
                 to: "/",
                 flash: %{"error" => "Access denied. Administrator privileges required."}
               }}} =
               live(conn, "/admin/frames")
    end

    test "unauthenticated user cannot access admin frame browser", %{conn: conn} do
      # Should redirect to login
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, "/admin/frames")
    end
  end

  describe "video selection" do
    test "displays available videos", %{conn: conn, admin_user: admin_user, video: video} do
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/frames")

      assert html =~ video.title
      assert html =~ "Duration:"
      assert html =~ "FPS:"
      assert html =~ "Frames:"
    end

    test "selecting a video loads frames", %{conn: conn, admin_user: admin_user, video: video} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames")

      # Select video
      render_click(view, "select_video", %{"video_id" => to_string(video.id)})

      # Check that frames are loaded
      html = render(view)
      # Check if video title appears anywhere
      assert html =~ video.title
    end

    test "URL parameter loads video directly", %{conn: conn, admin_user: admin_user, video: video} do
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Check if video title appears anywhere
      assert html =~ video.title
    end

    test "invalid video ID shows error", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)

      # Should redirect back with error
      assert {:error, {:live_redirect, %{to: "/admin/frames"}}} =
               live(conn, "/admin/frames?video_id=99999")
    end
  end

  describe "frame selection" do
    test "can select and deselect individual frames", %{
      conn: conn,
      admin_user: admin_user,
      video: video
    } do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Initially no frames selected
      assert :sys.get_state(view.pid).socket.assigns.selected_frame_indices == []

      # Select a frame
      render_click(view, "toggle_frame_selection", %{"frame_index" => "0"})
      assert :sys.get_state(view.pid).socket.assigns.selected_frame_indices == [0]

      # Deselect the frame
      render_click(view, "toggle_frame_selection", %{"frame_index" => "0"})
      assert :sys.get_state(view.pid).socket.assigns.selected_frame_indices == []
    end

    test "can select all frames", %{conn: conn, admin_user: admin_user, video: video} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Select all frames
      render_click(view, "select_all_frames")

      frame_count = length(:sys.get_state(view.pid).socket.assigns.frames)
      selected_indices = :sys.get_state(view.pid).socket.assigns.selected_frame_indices
      assert length(selected_indices) == frame_count
    end

    test "can deselect all frames", %{conn: conn, admin_user: admin_user, video: video} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Select some frames first
      render_click(view, "toggle_frame_selection", %{"frame_index" => "0"})
      render_click(view, "toggle_frame_selection", %{"frame_index" => "1"})
      assert length(:sys.get_state(view.pid).socket.assigns.selected_frame_indices) == 2

      # Deselect all
      render_click(view, "deselect_all_frames")
      assert :sys.get_state(view.pid).socket.assigns.selected_frame_indices == []
    end
  end

  describe "pagination" do
    test "handles pagination correctly", %{conn: conn, admin_user: admin_user, video: video} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Check initial page
      assert :sys.get_state(view.pid).socket.assigns.current_page == 1

      # Change page (if we had more frames)
      render_click(view, "change_page", %{"page" => "1"})
      assert :sys.get_state(view.pid).socket.assigns.current_page == 1
    end
  end

  describe "GIF generation" do
    test "shows error when no frames selected", %{
      conn: conn,
      admin_user: admin_user,
      video: video
    } do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Try to generate GIF with no frames selected
      render_click(view, "generate_gif")

      # Should show error flash
      assert render(view) =~ "Please select at least one frame"
    end

    test "starts GIF generation when frames are selected", %{
      conn: conn,
      admin_user: admin_user,
      video: video
    } do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Select some frames
      render_click(view, "toggle_frame_selection", %{"frame_index" => "0"})
      render_click(view, "toggle_frame_selection", %{"frame_index" => "1"})

      # Start GIF generation
      render_click(view, "generate_gif")

      # Should set generating status
      assert :sys.get_state(view.pid).socket.assigns.gif_generation_status == :generating
    end
  end

  describe "error handling" do
    test "handles invalid frame index gracefully", %{
      conn: conn,
      admin_user: admin_user,
      video: video
    } do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/frames?video_id=#{video.id}")

      # Try to select invalid frame index
      render_click(view, "toggle_frame_selection", %{"frame_index" => "invalid"})

      # Should show error
      assert render(view) =~ "Invalid frame index"
    end
  end
end
