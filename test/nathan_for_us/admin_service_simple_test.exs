defmodule NathanForUs.AdminServiceSimpleTest do
  use ExUnit.Case, async: true
  
  alias NathanForUs.AdminService
  
  describe "calculate_profile_coverage/1" do
    test "calculates coverage correctly" do
      stats = %{total_posts: 100, posts_with_users: 75}
      
      assert 75.0 = AdminService.calculate_profile_coverage(stats)
    end
    
    test "handles zero total posts" do
      stats = %{total_posts: 0, posts_with_users: 0}
      
      assert +0.0 = AdminService.calculate_profile_coverage(stats)
    end
    
    test "rounds to one decimal place" do
      stats = %{total_posts: 3, posts_with_users: 2}
      
      assert 66.7 = AdminService.calculate_profile_coverage(stats)
    end
  end
  
  describe "can_start_backfill?/1" do
    test "allows starting when not running" do
      assert true = AdminService.can_start_backfill?(false)
    end
    
    test "prevents starting when already running" do
      assert AdminService.can_start_backfill?(true) == false
    end
  end
  
  describe "parse_backfill_params/1" do
    test "parses valid parameters" do
      params = %{"limit" => "50", "dry_run" => "true"}
      
      assert {:ok, %{limit: 50, dry_run: true}} = 
        AdminService.parse_backfill_params(params)
    end
    
    test "parses dry_run false" do
      params = %{"limit" => "25", "dry_run" => "false"}
      
      assert {:ok, %{limit: 25, dry_run: false}} = 
        AdminService.parse_backfill_params(params)
    end
    
    test "handles invalid limit" do
      params = %{"limit" => "invalid", "dry_run" => "true"}
      
      assert {:error, "Invalid limit parameter"} = 
        AdminService.parse_backfill_params(params)
    end
    
    test "handles missing parameters" do
      params = %{"limit" => "50"}
      
      assert {:error, "Missing required parameters"} = 
        AdminService.parse_backfill_params(params)
      
      params = %{"dry_run" => "true"}
      
      assert {:error, "Missing required parameters"} = 
        AdminService.parse_backfill_params(params)
      
      params = %{}
      
      assert {:error, "Missing required parameters"} = 
        AdminService.parse_backfill_params(params)
    end
  end
  
  describe "handle_backfill_completion/1" do
    test "handles successful completion" do
      results = %{
        posts_found: 25,
        unique_dids: 20,
        successful: 18,
        failed: 2,
        dry_run: false
      }
      
      assert {:ok, enriched_results} = 
        AdminService.handle_backfill_completion({:ok, results})
      
      assert enriched_results.posts_found == 25
      assert enriched_results.successful == 18
      assert enriched_results.failed == 2
      assert enriched_results.completion_rate == 90.0
      assert %DateTime{} = enriched_results.timestamp
    end
    
    test "handles completion with no attempts" do
      results = %{
        posts_found: 0,
        unique_dids: 0,
        successful: 0,
        failed: 0,
        dry_run: true
      }
      
      assert {:ok, enriched_results} = 
        AdminService.handle_backfill_completion({:ok, results})
      
      assert enriched_results.completion_rate == 0.0
    end
    
    test "handles error completion" do
      assert {:error, "Backfill failed: :timeout"} = 
        AdminService.handle_backfill_completion({:error, :timeout})
    end
    
    test "handles timeout error" do
      assert {:error, "Backfill operation timed out"} = 
        AdminService.handle_backfill_completion({:error, {:timeout, "details"}})
    end
    
    test "handles killed error" do
      assert {:error, "Backfill operation was terminated"} = 
        AdminService.handle_backfill_completion({:error, :killed})
    end
  end
  
  describe "start_backfill/1 validation" do
    test "rejects invalid limit" do
      options = %{limit: -5, dry_run: true}
      
      assert {:error, "Limit must be greater than 0"} = 
        AdminService.start_backfill(options)
    end
    
    test "rejects limit too large" do
      options = %{limit: 2000, dry_run: true}
      
      assert {:error, "Limit cannot exceed 1000"} = 
        AdminService.start_backfill(options)
    end
    
    test "rejects non-integer limit" do
      options = %{limit: "invalid", dry_run: true}
      
      assert {:error, "Limit must be an integer"} = 
        AdminService.start_backfill(options)
    end
    
    test "rejects non-boolean dry_run" do
      options = %{limit: 50, dry_run: "invalid"}
      
      assert {:error, "Dry run must be true or false"} = 
        AdminService.start_backfill(options)
    end
  end
end