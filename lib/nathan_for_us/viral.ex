defmodule NathanForUs.Viral do
  @moduledoc """
  Context for managing viral GIFs and their interactions.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo
  alias NathanForUs.Viral.{ViralGif, GifInteraction, BrowseableGif, GifVote}

  @doc """
  Returns trending GIFs for public display (no auth required).
  """
  def get_trending_gifs(limit \\ 6) do
    # Get GIFs that have been viewed in the last 7 days, ordered by engagement
    cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)

    from(g in ViralGif,
      left_join: i in GifInteraction,
      on: g.id == i.viral_gif_id and i.inserted_at > ^cutoff,
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
      [gif] ->
        gif

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

  # === VOTING SYSTEM ===

  @doc """
  Votes on a browseable GIF. Handles both authenticated and anonymous votes.
  """
  def vote_on_gif(browseable_gif_id, vote_type, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    session_id = Keyword.get(opts, :session_id)
    ip_address = Keyword.get(opts, :ip_address)

    attrs = %{
      browseable_gif_id: browseable_gif_id,
      vote_type: vote_type,
      user_id: user_id,
      session_id: session_id,
      ip_address: ip_address
    }

    case %GifVote{} |> GifVote.changeset(attrs) |> Repo.insert() do
      {:ok, vote} ->
        update_gif_vote_counts(browseable_gif_id)
        {:ok, vote}

      {:error, changeset} ->
        # Handle existing vote - update instead of insert
        if changeset.errors[:user_id] || changeset.errors[:session_id] do
          update_existing_vote(browseable_gif_id, vote_type, user_id, session_id)
        else
          {:error, changeset}
        end
    end
  end

  defp update_existing_vote(browseable_gif_id, vote_type, user_id, session_id) do
    query =
      if user_id do
        from(v in GifVote,
          where: v.browseable_gif_id == ^browseable_gif_id and v.user_id == ^user_id
        )
      else
        from(v in GifVote,
          where: v.browseable_gif_id == ^browseable_gif_id and v.session_id == ^session_id
        )
      end

    case Repo.update_all(query, set: [vote_type: vote_type, updated_at: DateTime.utc_now()]) do
      {1, _} ->
        update_gif_vote_counts(browseable_gif_id)
        {:ok, :updated}

      {0, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets the current user's vote on a GIF.
  """
  def get_user_vote(browseable_gif_id, user_id: user_id) when not is_nil(user_id) do
    from(v in GifVote,
      where: v.browseable_gif_id == ^browseable_gif_id and v.user_id == ^user_id,
      select: v.vote_type
    )
    |> Repo.one()
  end

  def get_user_vote(browseable_gif_id, session_id: session_id) when not is_nil(session_id) do
    from(v in GifVote,
      where: v.browseable_gif_id == ^browseable_gif_id and v.session_id == ^session_id,
      select: v.vote_type
    )
    |> Repo.one()
  end

  def get_user_vote(_browseable_gif_id, _opts), do: nil

  @doc """
  Updates vote counts on the browseable GIF.
  """
  def update_gif_vote_counts(browseable_gif_id) do
    upvotes =
      from(v in GifVote,
        where: v.browseable_gif_id == ^browseable_gif_id and v.vote_type == "up",
        select: count(v.id)
      )
      |> Repo.one()

    downvotes =
      from(v in GifVote,
        where: v.browseable_gif_id == ^browseable_gif_id and v.vote_type == "down",
        select: count(v.id)
      )
      |> Repo.one()

    hot_score = calculate_hot_score(upvotes, downvotes, browseable_gif_id)

    from(g in BrowseableGif, where: g.id == ^browseable_gif_id)
    |> Repo.update_all(
      set: [
        upvotes_count: upvotes,
        downvotes_count: downvotes,
        hot_score: hot_score,
        hot_score_updated_at: DateTime.utc_now()
      ]
    )
  end

  @doc """
  Calculates Reddit-style hot score for ranking GIFs.
  """
  def calculate_hot_score(upvotes, downvotes, browseable_gif_id) do
    # Get GIF creation time
    gif_created_at =
      from(g in BrowseableGif,
        where: g.id == ^browseable_gif_id,
        select: g.inserted_at
      )
      |> Repo.one()

    if gif_created_at do
      calculate_hot_score_with_time(upvotes, downvotes, gif_created_at)
    else
      0.0
    end
  end

  defp calculate_hot_score_with_time(upvotes, downvotes, created_at) do
    # Reddit's hot algorithm with some modifications for our use case
    score = upvotes - downvotes

    # Time decay: newer posts get higher scores
    age_hours = DateTime.diff(DateTime.utc_now(), created_at, :hour)

    # Base score with logarithmic scaling for vote counts
    base_score =
      if score > 0 do
        :math.log10(max(score, 1))
      else
        -:math.log10(max(abs(score), 1))
      end

    # Time factor: posts lose points over time, but good content persists longer
    time_factor = :math.pow(age_hours + 2, 1.5)

    # Final hot score
    base_score / time_factor
  end

  @doc """
  Gets browseable GIFs ordered by hot score.
  """
  def get_hot_browseable_gifs(limit \\ 50) do
    from(g in BrowseableGif,
      where: g.is_public == true,
      order_by: [desc: g.hot_score, desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end

  @doc """
  Gets browseable GIFs ordered by total upvotes (all time).
  """
  def get_top_browseable_gifs(limit \\ 50) do
    from(g in BrowseableGif,
      where: g.is_public == true,
      order_by: [desc: g.upvotes_count, desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end

  @doc """
  Gets browseable GIFs ordered by recent upload time.
  """
  def get_new_browseable_gifs(limit \\ 50) do
    from(g in BrowseableGif,
      where: g.is_public == true,
      order_by: [desc: g.inserted_at],
      limit: ^limit,
      preload: [:video, :created_by_user, :gif]
    )
    |> Repo.all()
  end

  @doc """
  Bulk update hot scores for all GIFs (for background job).
  """
  def update_all_hot_scores do
    gifs =
      from(g in BrowseableGif,
        where: g.is_public == true,
        select: [:id, :upvotes_count, :downvotes_count, :inserted_at]
      )
      |> Repo.all()

    Enum.each(gifs, fn gif ->
      hot_score =
        calculate_hot_score_with_time(gif.upvotes_count, gif.downvotes_count, gif.inserted_at)

      from(g in BrowseableGif, where: g.id == ^gif.id)
      |> Repo.update_all(
        set: [
          hot_score: hot_score,
          hot_score_updated_at: DateTime.utc_now()
        ]
      )
    end)
  end
end
