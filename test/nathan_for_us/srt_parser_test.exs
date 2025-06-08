defmodule NathanForUs.SrtParserTest do
  use ExUnit.Case, async: true
  
  alias NathanForUs.SrtParser

  @sample_srt_content """
  1
  00:00:01,000 --> 00:00:03,000
  Hello world

  2
  00:00:04,500 --> 00:00:07,200
  This is a test subtitle
  with multiple lines

  3
  00:00:10,100 --> 00:00:12,500
  Another subtitle here
  """

  @sample_complex_srt """
  1
  00:00:00,500 --> 00:00:02,750
  Welcome to the show

  2
  00:01:15,250 --> 00:01:18,000
  Let's talk about trains
  and model railways

  3
  00:02:30,000 --> 00:02:33,500
  The sound of choo choo
  fills the air
  """

  describe "parse_content/1" do
    test "parses simple SRT content correctly" do
      {:ok, entries} = SrtParser.parse_content(@sample_srt_content)
      
      assert length(entries) == 3
      
      [first, second, third] = entries
      
      assert first.index == 1
      assert first.start_time == 1000
      assert first.end_time == 3000
      assert first.text == "Hello world"
      
      assert second.index == 2
      assert second.start_time == 4500
      assert second.end_time == 7200
      assert second.text == "This is a test subtitle with multiple lines"
      
      assert third.index == 3
      assert third.start_time == 10100
      assert third.end_time == 12500
      assert third.text == "Another subtitle here"
    end

    test "handles empty content" do
      {:ok, entries} = SrtParser.parse_content("")
      assert entries == []
    end

    test "handles malformed content gracefully" do
      malformed_content = """
      1
      invalid timing format
      Some text

      2
      00:00:01,000 --> 00:00:03,000
      Valid subtitle
      """
      
      {:ok, entries} = SrtParser.parse_content(malformed_content)
      
      # Should only parse the valid entry
      assert length(entries) == 1
      assert hd(entries).text == "Valid subtitle"
    end
  end

  describe "parse_file/1" do
    test "returns error for non-existent file" do
      result = SrtParser.parse_file("non_existent.srt")
      assert {:error, _reason} = result
    end

    test "parses actual SRT file if available" do
      # Create a temporary SRT file for testing
      temp_file = "test/tmp/test_#{System.unique_integer()}.srt"
      File.mkdir_p("test/tmp")
      File.write!(temp_file, @sample_srt_content)
      
      result = SrtParser.parse_file(temp_file)
      
      # Clean up
      File.rm(temp_file)
      
      assert {:ok, entries} = result
      assert length(entries) == 3
    end
  end

  describe "search_text/2" do
    setup do
      {:ok, entries} = SrtParser.parse_content(@sample_complex_srt)
      {:ok, %{entries: entries}}
    end

    test "finds entries containing search term", %{entries: entries} do
      results = SrtParser.search_text(entries, "train")
      
      assert length(results) == 1
      assert hd(results).text =~ "trains"
    end

    test "search is case insensitive", %{entries: entries} do
      results = SrtParser.search_text(entries, "CHOO")
      
      assert length(results) == 1
      assert hd(results).text =~ "choo choo"
    end

    test "finds multiple matching entries", %{entries: entries} do
      results = SrtParser.search_text(entries, "the")
      
      # Should find entries containing "the"
      assert length(results) >= 1
    end

    test "returns empty list when no matches found", %{entries: entries} do
      results = SrtParser.search_text(entries, "nonexistent")
      
      assert results == []
    end
  end

  describe "find_by_time_range/3" do
    setup do
      {:ok, entries} = SrtParser.parse_content(@sample_complex_srt)
      {:ok, %{entries: entries}}
    end

    test "finds entries overlapping with time range", %{entries: entries} do
      # Search from 1 second to 2 seconds (1000ms to 2000ms)
      results = SrtParser.find_by_time_range(entries, 1000, 2000)
      
      # Should find the first entry (500ms to 2750ms)
      assert length(results) == 1
      assert hd(results).text == "Welcome to the show"
    end

    test "finds multiple overlapping entries", %{entries: entries} do
      # Search a broader range
      results = SrtParser.find_by_time_range(entries, 0, 180000)  # 0 to 3 minutes
      
      # Should find all entries
      assert length(results) == 3
    end

    test "returns empty list when no overlap", %{entries: entries} do
      # Search in a gap between subtitles
      results = SrtParser.find_by_time_range(entries, 200000, 300000)  # 3+ minutes
      
      assert results == []
    end
  end

  describe "find_at_timestamp/2" do
    setup do
      {:ok, entries} = SrtParser.parse_content(@sample_complex_srt)
      {:ok, %{entries: entries}}
    end

    test "finds entry active at specific timestamp", %{entries: entries} do
      # 1.5 seconds should be in the first subtitle
      result = SrtParser.find_at_timestamp(entries, 1500)
      
      assert result != nil
      assert result.text == "Welcome to the show"
    end

    test "returns nil when no entry active at timestamp", %{entries: entries} do
      # 5 seconds should be between subtitles
      result = SrtParser.find_at_timestamp(entries, 5000)
      
      assert result == nil
    end
  end

  describe "build_timestamp_index/1" do
    setup do
      {:ok, entries} = SrtParser.parse_content(@sample_complex_srt)
      {:ok, %{entries: entries}}
    end

    test "builds timestamp index grouped by seconds", %{entries: entries} do
      index = SrtParser.build_timestamp_index(entries)
      
      assert is_map(index)
      
      # First subtitle spans from 0.5s to 2.75s, so should be in seconds 0, 1, 2
      assert Map.has_key?(index, 0)
      assert Map.has_key?(index, 1)
      assert Map.has_key?(index, 2)
      
      # Check that the entries are correctly indexed
      entries_at_1s = Map.get(index, 1)
      assert is_list(entries_at_1s)
      assert length(entries_at_1s) == 1
      assert hd(entries_at_1s).text == "Welcome to the show"
    end

    test "handles overlapping subtitles in index", %{entries: entries} do
      # Add an overlapping subtitle for testing
      overlapping_entry = %SrtParser{
        index: 4,
        start_time: 1000,   # 1 second
        end_time: 3000,     # 3 seconds
        text: "Overlapping subtitle"
      }
      
      all_entries = entries ++ [overlapping_entry]
      index = SrtParser.build_timestamp_index(all_entries)
      
      # Second 1 should have multiple entries
      entries_at_1s = Map.get(index, 1)
      assert length(entries_at_1s) >= 2
    end
  end

  describe "timestamp parsing edge cases" do
    test "handles different millisecond formats" do
      srt_with_different_ms = """
      1
      00:00:01,500 --> 00:00:03,750
      Test subtitle
      """
      
      {:ok, entries} = SrtParser.parse_content(srt_with_different_ms)
      
      assert length(entries) == 1
      assert hd(entries).start_time == 1500
      assert hd(entries).end_time == 3750
    end

    test "handles hour timestamps correctly" do
      srt_with_hours = """
      1
      01:30:15,250 --> 01:30:18,500
      Long video subtitle
      """
      
      {:ok, entries} = SrtParser.parse_content(srt_with_hours)
      
      assert length(entries) == 1
      # 1 hour, 30 minutes, 15.25 seconds = 5415250 milliseconds
      assert hd(entries).start_time == 5415250
      # 1 hour, 30 minutes, 18.5 seconds = 5418500 milliseconds
      assert hd(entries).end_time == 5418500
    end
  end
end