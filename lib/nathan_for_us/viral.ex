defmodule NathanForUs.Viral do
  @moduledoc """
  Context for managing viral GIFs and their interactions.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo
  alias NathanForUs.Viral.{ViralGif, GifInteraction, BrowseableGif}

  @doc """
  Returns trending GIFs for public display (no auth required).
  """
  def get_trending_gifs(limit \\ 6) do
    # Get GIFs that have been viewed in the last 7 days, ordered by engagement
    cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)
    
    from(g in ViralGif,
      left_join: i in GifInteraction, on: g.id == i.viral_gif_id and i.inserted_at > ^cutoff,
      group_by: g.id,
      order_by: [desc: fragment("COUNT(?) + ? * 2", i.id, g.share_count), desc: g.view_count],
      limit: ^limit,
      preload: [:video, :created_by_user]
    )
    |> Repo.all()
  end

  @doc """
  Returns most recent GIFs for public timeline.
  """
  def get_recent_gifs(limit \\ 25) do
    from(g in ViralGif,
      order_by: [desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end

  @doc """
  Gets featured GIFs for the landing page.
  """
  def get_featured_gifs(limit \\ 4) do
    from(g in ViralGif,
      where: g.is_featured == true,
      order_by: [desc: g.view_count],
      limit: ^limit,
      preload: [:video, :created_by_user]
    )
    |> Repo.all()
  end

  @doc """
  Gets a random Nathan moment for discovery.
  """
  def get_random_moment do
    # Get a random featured GIF or fall back to any popular one
    featured = get_featured_gifs(1)
    
    case featured do
      [gif] -> gif
      [] -> 
        from(g in ViralGif,
          where: g.view_count > 0,
          order_by: fragment("RANDOM()"),
          limit: 1,
          preload: [:video, :created_by_user]
        )
        |> Repo.one()
    end
  end

  @doc """
  Creates a viral GIF from frame selection.
  """
  def create_viral_gif(attrs \\ %{}) do
    %ViralGif{}
    |> ViralGif.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Records a GIF interaction (view, share, download).
  """
  def record_interaction(viral_gif_id, interaction_type, opts \\ []) do
    attrs = %{
      viral_gif_id: viral_gif_id,
      interaction_type: interaction_type,
      user_id: Keyword.get(opts, :user_id),
      session_id: Keyword.get(opts, :session_id),
      platform: Keyword.get(opts, :platform)
    }

    %GifInteraction{}
    |> GifInteraction.changeset(attrs)
    |> Repo.insert()

    # Update counters on the viral gif
    case interaction_type do
      "view" -> increment_view_count(viral_gif_id)
      "share" -> increment_share_count(viral_gif_id)
      _ -> :ok
    end
  end

  defp increment_view_count(viral_gif_id) do
    from(g in ViralGif, where: g.id == ^viral_gif_id)
    |> Repo.update_all(inc: [view_count: 1])
  end

  defp increment_share_count(viral_gif_id) do
    from(g in ViralGif, where: g.id == ^viral_gif_id)
    |> Repo.update_all(inc: [share_count: 1])
  end

  @doc """
  Gets GIFs by category for meme templates.
  """
  def get_gifs_by_category(category, limit \\ 10) do
    from(g in ViralGif,
      where: g.category == ^category,
      order_by: [desc: g.view_count],
      limit: ^limit,
      preload: [:video, :created_by_user]
    )
    |> Repo.all()
  end

  @doc """
  Gets all available categories.
  """
  def get_categories do
    from(g in ViralGif,
      where: not is_nil(g.category),
      distinct: g.category,
      select: g.category
    )
    |> Repo.all()
  end

  @doc """
  Popular Nathan moment categories for viral potential.
  """
  def nathan_categories do
    [
      "awkward_silence",
      "business_genius", 
      "confused_stare",
      "dramatic_pause",
      "summit_ice",
      "the_plan",
      "rehearsal_prep",
      "uncomfortable_truth"
    ]
  end

  @doc """
  Creates a browseable GIF entry automatically when someone generates a GIF.
  This makes ALL generated GIFs browseable for inspiration, regardless of posting.
  """
  def create_browseable_gif(attrs \\ %{}) do
    %BrowseableGif{}
    |> BrowseableGif.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets recent browseable GIFs for the browse page.
  """
  def get_recent_browseable_gifs(limit \\ 50) do
    from(g in BrowseableGif,
      where: g.is_public == true,
      order_by: [desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end

  @doc """
  Gets browseable GIFs by category.
  """
  def get_browseable_gifs_by_category(category, limit \\ 20) do
    from(g in BrowseableGif,
      where: g.category == ^category and g.is_public == true,
      order_by: [desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end

  @doc """
  Gets browseable GIFs for a specific video.
  """
  def get_browseable_gifs_for_video(video_id, limit \\ 20) do
    from(g in BrowseableGif,
      where: g.video_id == ^video_id and g.is_public == true,
      order_by: [desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end
end