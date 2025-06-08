defmodule NathanForUsWeb.FrameImageController do
  use NathanForUsWeb, :controller
  
  alias NathanForUs.Video

  def show(conn, %{"id" => frame_id}) do
    case Video.get_frame_image_data(frame_id) do
      {:ok, image_data} ->
        conn
        |> put_resp_content_type("image/jpeg")
        |> put_resp_header("cache-control", "public, max-age=86400")  # Cache for 1 day
        |> send_resp(200, image_data)
      
      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> text("Frame not found")
    end
  end
end