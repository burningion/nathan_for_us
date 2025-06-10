defmodule NathanForUs.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo

  alias NathanForUs.Chat.{Word, ChatMessage}

  @doc """
  Returns the list of words pending approval.
  """
  def list_pending_words do
    from(w in Word,
      where: w.status == "pending" and w.banned_forever == false,
      order_by: [asc: w.inserted_at],
      preload: [:submitted_by]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of approved words.
  """
  def list_approved_words do
    from(w in Word,
      where: w.status == "approved",
      select: w.text
    )
    |> Repo.all()
    |> Enum.shuffle()
  end

  @doc """
  Gets a single word.
  """
  def get_word!(id), do: Repo.get!(Word, id)

  @doc """
  Creates a word submission.
  """
  def create_word(attrs \\ %{}) do
    %Word{}
    |> Word.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, word} ->
        word_with_user = Repo.preload(word, :submitted_by)
        Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:word_submitted, word_with_user})
        {:ok, word}
      error -> error
    end
  end

  @doc """
  Submits a word for approval. If the word already exists and was denied,
  increments submission count. If submitted 5 times, bans forever.
  """
  def submit_word(text, user_id) do
    normalized_text = String.downcase(String.trim(text))

    case from(w in Word, where: fragment("lower(?)", w.text) == ^normalized_text)
         |> Repo.one() do
      nil ->
        create_word(%{text: normalized_text, submitted_by_id: user_id})

      %Word{status: "approved"} ->
        {:error, :already_approved}

      %Word{banned_forever: true} ->
        {:error, :banned_forever}

      %Word{status: "denied", submission_count: count} = word when count >= 5 ->
        word
        |> Word.changeset(%{banned_forever: true})
        |> Repo.update()
        {:error, :banned_forever}

      %Word{status: "denied", submission_count: count} = word ->
        word
        |> Word.changeset(%{
          status: "pending",
          submission_count: count + 1,
          submitted_by_id: user_id,
          approved_by_id: nil
        })
        |> Repo.update()
        |> case do
          {:ok, updated_word} ->
            word_with_user = Repo.preload(updated_word, :submitted_by)
            Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:word_submitted, word_with_user})
            {:ok, updated_word}
          error -> error
        end

      %Word{status: "pending"} ->
        {:error, :already_pending}
    end
  end

  @doc """
  Approves a word.
  """
  def approve_word(word_id, approver_id) do
    word = get_word!(word_id)

    if word.submitted_by_id == approver_id do
      {:error, :cannot_approve_own_word}
    else
      word
      |> Word.changeset(%{status: "approved", approved_by_id: approver_id})
      |> Repo.update()
      |> case do
        {:ok, updated_word} ->
          # Broadcast word approval
          Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:word_approved, updated_word})
          
          # Check if any previously rejected messages can now be validated
          case revalidate_rejected_messages() do
            {:ok, [_ | _] = newly_valid_messages} ->
              # Broadcast that messages were retroactively validated
              Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:messages_revalidated, length(newly_valid_messages)})
            
            {:ok, []} ->
              :ok
          end
          
          {:ok, updated_word}
        error -> error
      end
    end
  end

  @doc """
  Denies a word.
  """
  def deny_word(word_id, denier_id) do
    word = get_word!(word_id)

    if word.submitted_by_id == denier_id do
      {:error, :cannot_deny_own_word}
    else
      word
      |> Word.changeset(%{status: "denied"})
      |> Repo.update()
      |> case do
        {:ok, updated_word} ->
          Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:word_denied, updated_word})
          {:ok, updated_word}
        error -> error
      end
    end
  end

  @doc """
  Validates if a message contains only approved words.
  Links are allowed and will be replaced with "surprise me" in display.
  """
  def validate_message_words(content) do
    approved_words =
      list_approved_words()
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    # Extract and remove URLs from validation
    words = String.split(content)
    
    text_words = 
      words
      |> Enum.reject(&is_url?/1)
      |> Enum.join(" ")

    text_words
    |> String.downcase()
    |> String.replace(~r/[^\w\s']/, " ")
    |> String.split()
    |> Enum.reject(&(&1 == ""))
    |> Enum.all?(&MapSet.member?(approved_words, &1))
  end

  def is_url?(word) do
    case URI.parse(word) do
      %URI{scheme: scheme} when scheme in ["http", "https"] -> true
      _ -> false
    end
  end

  @doc """
  Returns the list of valid chat messages for display.
  """
  def list_chat_messages(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(cm in ChatMessage,
      where: cm.valid == true,
      order_by: [desc: cm.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Gets the total count of all valid chat messages.
  """
  def get_total_message_count do
    from(cm in ChatMessage,
      where: cm.valid == true,
      select: count(cm.id)
    )
    |> Repo.one()
  end

  @doc """
  Processes message content for display, replacing URLs with "surprise me" links.
  """
  def process_message_for_display(content) do
    content
    |> String.split()
    |> Enum.map(&process_word/1)
    |> Enum.join(" ")
  end

  defp process_word(word) do
    if is_url?(word) do
      "surprise me"
    else
      word
    end
  end

  @doc """
  Returns all chat messages (including invalid ones) for admin purposes.
  """
  def list_all_chat_messages(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(cm in ChatMessage,
      order_by: [asc: cm.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Returns only rejected (invalid) chat messages.
  """
  def list_rejected_messages(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    from(cm in ChatMessage,
      where: cm.valid == false,
      order_by: [desc: cm.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Checks all invalid messages and marks them as valid if they now contain only approved words.
  Returns a list of newly validated messages that should be broadcast to the chat.
  """
  def revalidate_rejected_messages do
    # Get all currently invalid messages
    invalid_messages = 
      from(cm in ChatMessage,
        where: cm.valid == false,
        preload: [:user]
      )
      |> Repo.all()

    # Check each message against current approved words
    newly_valid_messages = 
      Enum.filter(invalid_messages, fn message ->
        validate_message_words(message.content)
      end)

    # Update the newly valid messages in the database
    case newly_valid_messages do
      [] -> 
        {:ok, []}
      
      messages ->
        message_ids = Enum.map(messages, & &1.id)
        
        # Update all newly valid messages in one query
        {_updated_count, _} = 
          from(cm in ChatMessage,
            where: cm.id in ^message_ids
          )
          |> Repo.update_all(set: [valid: true, updated_at: DateTime.utc_now()])

        # Broadcast each newly valid message to the chat
        Enum.each(messages, fn message ->
          # Update the message struct to reflect the new valid status
          updated_message = %{message | valid: true}
          Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:new_message, updated_message})
        end)

        {:ok, messages}
    end
  end

  @doc """
  Gets a single chat message.
  """
  def get_chat_message!(id), do: Repo.get!(ChatMessage, id)

  @doc """
  Creates a chat message and marks it as valid or invalid based on word approval.
  Always saves the message for record-keeping.
  """
  def create_chat_message(attrs \\ %{}) do
    content = Map.get(attrs, "content") || Map.get(attrs, :content)
    is_valid = validate_message_words(content)

    attrs_with_validity = Map.put(attrs, :valid, is_valid)

    %ChatMessage{}
    |> ChatMessage.changeset(attrs_with_validity)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message_with_user = Repo.preload(message, :user)

        # Only broadcast valid messages to the chat
        if is_valid do
          Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:new_message, message_with_user})
        end

        {:ok, message_with_user, is_valid}
      error -> error
    end
  end

  @doc """
  Updates a chat message.
  """
  def update_chat_message(%ChatMessage{} = chat_message, attrs) do
    chat_message
    |> ChatMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a chat message.
  """
  def delete_chat_message(%ChatMessage{} = chat_message) do
    Repo.delete(chat_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chat message changes.
  """
  def change_chat_message(%ChatMessage{} = chat_message, attrs \\ %{}) do
    ChatMessage.changeset(chat_message, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word changes.
  """
  def change_word(%Word{} = word, attrs \\ %{}) do
    Word.changeset(word, attrs)
  end

  @doc """
  Seeds common words as approved for admin purposes.
  """
  def seed_common_words(admin_user_id) do
    common_words = [
      "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
      "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
      "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
      "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
      "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
      "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
      "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
      "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
      "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
      "even", "new", "want", "because", "any", "these", "give", "day", "most", "us"
    ]

    results = Enum.map(common_words, fn word ->
      case from(w in Word, where: fragment("lower(?)", w.text) == ^word) |> Repo.one() do
        nil ->
          %Word{}
          |> Word.changeset(%{
            text: word,
            status: "approved",
            submitted_by_id: admin_user_id,
            approved_by_id: admin_user_id
          })
          |> Repo.insert()

        existing_word ->
          existing_word
          |> Word.changeset(%{status: "approved", approved_by_id: admin_user_id})
          |> Repo.update()
      end
    end)

    successes = Enum.count(results, fn {status, _} -> status == :ok end)

    # Broadcast that approved words have been updated
    Phoenix.PubSub.broadcast(NathanForUs.PubSub, "chat_room", {:words_bulk_approved, successes})

    {:ok, successes}
  end
end
