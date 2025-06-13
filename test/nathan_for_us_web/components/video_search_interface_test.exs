defmodule NathanForUsWeb.Components.VideoSearch.SearchInterfaceTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest
  alias NathanForUsWeb.Components.VideoSearch.SearchInterface

  describe "search_interface/1" do
    test "renders search interface with basic attributes" do
      assigns = %{
        search_term: "test query",
        search_form: %{"term" => "test query"},
        loading: false,
        videos: [],
        search_mode: :global,
        selected_video_ids: [],
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: ["Sample suggestion 1", "Sample suggestion 2"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_interface
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        videos={@videos}
        search_mode={@search_mode}
        selected_video_ids={@selected_video_ids}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should contain main structure
      assert html =~ "SEARCH INTERFACE"
      assert html =~ "Random Clip"
      assert html =~ "Enter search query for spoken dialogue..."
    end

    test "passes sample suggestions to search form" do
      sample_suggestions = ["Business strategy", "Rehearsal preparation", "Nathan's plan"]
      
      assigns = %{
        search_term: "",
        search_form: %{"term" => ""},
        loading: false,
        videos: [],
        search_mode: :global,
        selected_video_ids: [],
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: sample_suggestions
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_interface
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        videos={@videos}
        search_mode={@search_mode}
        selected_video_ids={@selected_video_ids}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should render the search form component with sample suggestions
      assert html =~ "TRY SEARCHING FOR"
      Enum.each(sample_suggestions, fn suggestion ->
        assert html =~ suggestion
      end)
    end
  end

  describe "search_form/1" do
    test "renders search form with empty search term" do
      assigns = %{
        search_term: "",
        search_form: %{"term" => ""},
        loading: false,
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: ["Sample 1", "Sample 2", "Sample 3"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_form
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should show sample suggestions when search is empty
      assert html =~ "TRY SEARCHING FOR"
      assert html =~ "Sample 1"
      assert html =~ "Sample 2"
      assert html =~ "Sample 3"
      
      # Should have search input
      assert html =~ "search[term]"
      assert html =~ "Enter search query for spoken dialogue..."
      assert html =~ "EXECUTE"
    end

    test "renders search form with non-empty search term" do
      assigns = %{
        search_term: "business",
        search_form: %{"term" => "business"},
        loading: false,
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: ["Sample 1", "Sample 2"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_form
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should NOT show sample suggestions when search has content
      refute html =~ "TRY SEARCHING FOR"
      refute html =~ "Sample 1"
      
      # Should show search input with value
      assert html =~ "business"
      assert html =~ "EXECUTE"
    end

    test "renders search form with autocomplete showing" do
      assigns = %{
        search_term: "test",
        search_form: %{"term" => "test"},
        loading: false,
        autocomplete_suggestions: ["test suggestion 1", "test suggestion 2"],
        show_autocomplete: true,
        sample_suggestions: ["Sample 1", "Sample 2"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_form
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should show autocomplete dropdown
      assert html =~ "SUGGESTED PHRASES"
      assert html =~ "test suggestion 1"
      assert html =~ "test suggestion 2"
      
      # Should NOT show sample suggestions when autocomplete is active
      refute html =~ "TRY SEARCHING FOR"
      refute html =~ "Sample 1"
    end

    test "renders loading state correctly" do
      assigns = %{
        search_term: "loading test",
        search_form: %{"term" => "loading test"},
        loading: true,
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: []
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_form
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should show loading state
      assert html =~ "SEARCHING"
      assert html =~ "disabled"
    end
  end

  describe "sample_suggestions_display/1" do
    test "renders sample suggestions correctly" do
      suggestions = [
        "I graduated from business school",
        "The plan is working perfectly", 
        "I'm prepared for anything",
        "This is a business strategy"
      ]

      assigns = %{suggestions: suggestions}

      html = rendered_to_string(~H"""
      <SearchInterface.sample_suggestions_display suggestions={@suggestions} />
      """)

      # Should contain section header
      assert html =~ "TRY SEARCHING FOR"
      
      # Should contain all suggestions as clickable buttons
      Enum.each(suggestions, fn suggestion ->
        assert html =~ suggestion
      end)
      
      # Should have correct event handlers
      assert html =~ "phx-click=\"select_sample_suggestion\""
      assert html =~ "phx-value-suggestion="
      
      # Should have proper CSS classes for layout
      assert html =~ "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
      assert html =~ "hover:bg-blue-50"
    end

    test "renders empty suggestions gracefully" do
      assigns = %{suggestions: []}

      html = rendered_to_string(~H"""
      <SearchInterface.sample_suggestions_display suggestions={@suggestions} />
      """)

      # Should still render the structure
      assert html =~ "TRY SEARCHING FOR"
      
      # But no suggestion buttons
      refute html =~ "phx-click=\"select_sample_suggestion\""
    end

    test "handles long suggestions correctly" do
      long_suggestions = [
        "This is a moderately long business strategy suggestion",
        "Another somewhat lengthy quote from Nathan's interviews"
      ]

      assigns = %{suggestions: long_suggestions}

      html = rendered_to_string(~H"""
      <SearchInterface.sample_suggestions_display suggestions={@suggestions} />
      """)

      # Should render long suggestions
      Enum.each(long_suggestions, fn suggestion ->
        assert html =~ suggestion
      end)
      
      # Should have proper styling for text truncation if needed
      assert html =~ "font-mono"
    end

    test "suggestion buttons have proper accessibility attributes" do
      suggestions = ["Business strategy", "Rehearsal plan"]
      assigns = %{suggestions: suggestions}

      html = rendered_to_string(~H"""
      <SearchInterface.sample_suggestions_display suggestions={@suggestions} />
      """)

      # Should have title attributes for accessibility
      assert html =~ "title=\"Click to search for:"
      
      # Should be proper button elements
      assert html =~ "<button"
      assert html =~ "type=\"button\""
    end

    test "suggestion buttons have correct styling classes" do
      suggestions = ["Test suggestion"]
      assigns = %{suggestions: suggestions}

      html = rendered_to_string(~H"""
      <SearchInterface.sample_suggestions_display suggestions={@suggestions} />
      """)

      # Should have proper styling classes
      assert html =~ "text-left"
      assert html =~ "px-3 py-2"
      assert html =~ "text-sm"
      assert html =~ "text-zinc-700"
      assert html =~ "bg-zinc-50"
      assert html =~ "hover:bg-blue-50"
      assert html =~ "hover:text-blue-700"
      assert html =~ "border border-zinc-200"
      assert html =~ "hover:border-blue-300"
      assert html =~ "rounded-lg"
      assert html =~ "font-mono"
      assert html =~ "transition-colors"
    end
  end

  describe "autocomplete_dropdown/1" do
    test "renders autocomplete suggestions" do
      suggestions = ["business strategy", "business plan", "business meeting"]
      assigns = %{suggestions: suggestions}

      html = rendered_to_string(~H"""
      <SearchInterface.autocomplete_dropdown suggestions={@suggestions} />
      """)

      # Should contain header
      assert html =~ "SUGGESTED PHRASES"
      
      # Should contain all suggestions
      Enum.each(suggestions, fn suggestion ->
        assert html =~ suggestion
      end)
      
      # Should have correct event handlers
      assert html =~ "phx-click=\"select_suggestion\""
      assert html =~ "phx-click-away=\"hide_autocomplete\""
    end

    test "handles empty autocomplete suggestions" do
      assigns = %{suggestions: []}

      html = rendered_to_string(~H"""
      <SearchInterface.autocomplete_dropdown suggestions={@suggestions} />
      """)

      # Should still render structure
      assert html =~ "SUGGESTED PHRASES"
      
      # But no suggestion buttons
      refute html =~ "phx-click=\"select_suggestion\""
    end
  end

  describe "compact_random_clip_button/1" do
    test "renders random clip button" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <SearchInterface.compact_random_clip_button />
      """)

      # Should contain button with correct text and handler
      assert html =~ "Random Clip"
      assert html =~ "phx-click=\"generate_random_clip\""
      assert html =~ "Generate a random 5-second Nathan clip"
      
      # Should have proper styling
      assert html =~ "bg-blue-600"
      assert html =~ "hover:bg-blue-700"
      assert html =~ "text-white"
    end
  end

  describe "integration with different states" do
    test "empty search state shows sample suggestions" do
      assigns = %{
        search_term: "",
        search_form: %{"term" => ""},
        loading: false,
        videos: [],
        search_mode: :global,
        selected_video_ids: [],
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: ["Business", "Strategy", "Plan"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_interface
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        videos={@videos}
        search_mode={@search_mode}
        selected_video_ids={@selected_video_ids}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      assert html =~ "TRY SEARCHING FOR"
      assert html =~ "Business"
      assert html =~ "Strategy"
      assert html =~ "Plan"
    end

    test "search with content hides sample suggestions" do
      assigns = %{
        search_term: "business",
        search_form: %{"term" => "business"},
        loading: false,
        videos: [],
        search_mode: :global,
        selected_video_ids: [],
        autocomplete_suggestions: [],
        show_autocomplete: false,
        sample_suggestions: ["Business", "Strategy", "Plan"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_interface
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        videos={@videos}
        search_mode={@search_mode}
        selected_video_ids={@selected_video_ids}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      refute html =~ "TRY SEARCHING FOR"
      # Business might still appear in the input value, but not as a suggestion
      refute html =~ "phx-click=\"select_sample_suggestion\""
    end

    test "autocomplete active hides sample suggestions" do
      assigns = %{
        search_term: "bus",
        search_form: %{"term" => "bus"},
        loading: false,
        videos: [],
        search_mode: :global,
        selected_video_ids: [],
        autocomplete_suggestions: ["business strategy", "business plan"],
        show_autocomplete: true,
        sample_suggestions: ["Sample 1", "Sample 2"]
      }

      html = rendered_to_string(~H"""
      <SearchInterface.search_interface
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        videos={@videos}
        search_mode={@search_mode}
        selected_video_ids={@selected_video_ids}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
        sample_suggestions={@sample_suggestions}
      />
      """)

      # Should show autocomplete
      assert html =~ "SUGGESTED PHRASES"
      assert html =~ "business strategy"
      
      # Should NOT show sample suggestions
      refute html =~ "TRY SEARCHING FOR"
      refute html =~ "Sample 1"
    end
  end
end