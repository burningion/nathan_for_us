defmodule NathanForUs.SrtParser do
  @moduledoc """
  Parser for SRT (SubRip Text) subtitle files.
  Converts subtitle entries to structured data with timestamps and text.
  """

  require Logger

  defstruct [:index, :start_time, :end_time, :text]

  @type subtitle_entry :: %__MODULE__{
          index: integer(),
          start_time: integer(),
          end_time: integer(),
          text: String.t()
        }

  @doc """
  Parses an SRT file and returns a list of subtitle entries.
  Timestamps are converted to milliseconds for easier processing.
  
  ## Example
      iex> NathanForUs.SrtParser.parse_file("path/to/subtitles.srt")
      {:ok, [
        %NathanForUs.SrtParser{
          index: 1,
          start_time: 1000,
          end_time: 3000,
          text: "Hello world"
        }
      ]}
  """
  def parse_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, entries} <- parse_content(content) do
      Logger.info("Parsed #{length(entries)} subtitle entries from #{file_path}")
      {:ok, entries}
    else
      {:error, reason} ->
        Logger.error("Failed to parse SRT file #{file_path}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Parses SRT content string and returns subtitle entries.
  """
  def parse_content(content) when is_binary(content) do
    entries =
      content
      |> String.trim()
      |> String.split(~r/\n\s*\n/)
      |> Enum.map(&parse_subtitle_block/1)
      |> Enum.reject(&is_nil/1)

    {:ok, entries}
  rescue
    error ->
      {:error, "Parse error: #{Exception.message(error)}"}
  end

  @doc """
  Finds subtitle entries that contain the given search text.
  Search is case-insensitive and supports partial matches.
  """
  def search_text(entries, search_term) when is_list(entries) and is_binary(search_term) do
    normalized_search = String.downcase(search_term)

    entries
    |> Enum.filter(fn entry ->
      entry.text
      |> String.downcase()
      |> String.contains?(normalized_search)
    end)
  end

  @doc """
  Finds subtitle entries that overlap with a given time range (in milliseconds).
  """
  def find_by_time_range(entries, start_ms, end_ms) when is_list(entries) do
    entries
    |> Enum.filter(fn entry ->
      # Check if subtitle overlaps with the given time range
      entry.start_time < end_ms and entry.end_time > start_ms
    end)
  end

  @doc """
  Finds the subtitle entry active at a specific timestamp (in milliseconds).
  """
  def find_at_timestamp(entries, timestamp_ms) when is_list(entries) do
    entries
    |> Enum.find(fn entry ->
      timestamp_ms >= entry.start_time and timestamp_ms <= entry.end_time
    end)
  end

  @doc """
  Converts subtitle entries to a map for frame-to-caption lookup.
  Groups by second intervals for efficient searching.
  """
  def build_timestamp_index(entries) when is_list(entries) do
    entries
    |> Enum.reduce(%{}, fn entry, acc ->
      # Create entries for each second the subtitle is active
      start_second = div(entry.start_time, 1000)
      end_second = div(entry.end_time, 1000)

      Enum.reduce(start_second..end_second, acc, fn second, acc_inner ->
        Map.update(acc_inner, second, [entry], fn existing ->
          [entry | existing]
        end)
      end)
    end)
    |> Enum.into(%{}, fn {second, entries} ->
      {second, Enum.reverse(entries)}
    end)
  end

  # Private functions

  defp parse_subtitle_block(block) when is_binary(block) do
    lines = String.split(block, "\n") |> Enum.map(&String.trim/1)

    case lines do
      [index_str, timing_str | text_lines] ->
        with {:ok, index} <- parse_index(index_str),
             {:ok, start_time, end_time} <- parse_timing(timing_str),
             text when text != "" <- parse_text(text_lines) do
          %__MODULE__{
            index: index,
            start_time: start_time,
            end_time: end_time,
            text: text
          }
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_index(index_str) do
    case Integer.parse(index_str) do
      {index, _} -> {:ok, index}
      :error -> {:error, "Invalid index: #{index_str}"}
    end
  end

  defp parse_timing(timing_str) do
    # Format: "00:00:01,000 --> 00:00:03,000"
    case String.split(timing_str, " --> ") do
      [start_str, end_str] ->
        with {:ok, start_time} <- parse_timestamp(start_str),
             {:ok, end_time} <- parse_timestamp(end_str) do
          {:ok, start_time, end_time}
        else
          error -> error
        end

      _ ->
        {:error, "Invalid timing format: #{timing_str}"}
    end
  end

  defp parse_timestamp(timestamp_str) do
    # Format: "00:00:01,000" (hours:minutes:seconds,milliseconds)
    case String.split(timestamp_str, ",") do
      [time_part, ms_part] ->
        with {:ok, ms} <- parse_milliseconds(ms_part),
             {:ok, base_ms} <- parse_time_part(time_part) do
          {:ok, base_ms + ms}
        else
          error -> error
        end

      _ ->
        {:error, "Invalid timestamp format: #{timestamp_str}"}
    end
  end

  defp parse_milliseconds(ms_str) do
    case Integer.parse(ms_str) do
      {ms, _} -> {:ok, ms}
      :error -> {:error, "Invalid milliseconds: #{ms_str}"}
    end
  end

  defp parse_time_part(time_str) do
    case String.split(time_str, ":") do
      [hours_str, minutes_str, seconds_str] ->
        with {:ok, hours} <- safe_parse_int(hours_str),
             {:ok, minutes} <- safe_parse_int(minutes_str),
             {:ok, seconds} <- safe_parse_int(seconds_str) do
          total_ms = (hours * 3600 + minutes * 60 + seconds) * 1000
          {:ok, total_ms}
        else
          error -> error
        end

      _ ->
        {:error, "Invalid time format: #{time_str}"}
    end
  end

  defp safe_parse_int(str) do
    case Integer.parse(str) do
      {int, _} -> {:ok, int}
      :error -> {:error, "Invalid integer: #{str}"}
    end
  end

  defp parse_text(text_lines) do
    text_lines
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    |> String.trim()
  end
end