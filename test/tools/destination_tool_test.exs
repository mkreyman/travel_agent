defmodule TravelAgent.Tools.DestinationToolTest do
  use ExUnit.Case, async: true

  alias TravelAgent.Tools.DestinationTool
  alias TravelAgent.Tools.ToolBehaviour

  describe "behaviour implementation" do
    test "name/0 returns tool name" do
      assert DestinationTool.name() == "search_destinations"
    end

    test "description/0 returns tool description" do
      description = DestinationTool.description()
      assert is_binary(description)
      assert String.contains?(description, "destination")
    end

    test "parameters/0 returns valid JSON schema" do
      params = DestinationTool.parameters()
      assert params["type"] == "object"
      assert is_map(params["properties"])
      assert Map.has_key?(params["properties"], "travel_type")
      assert Map.has_key?(params["properties"], "budget_level")
      assert Map.has_key?(params["properties"], "region_preference")
      assert params["required"] == ["travel_type"]
    end
  end

  describe "execute/1" do
    test "returns destinations for beach travel type" do
      args = %{"travel_type" => "beach relaxation"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert is_binary(result)
      assert String.contains?(result, "Found")
      assert String.contains?(result, "matching destinations")
      # Should include beach destinations
      assert String.contains?(result, "Bali") or String.contains?(result, "Maldives")
    end

    test "returns destinations for adventure travel type" do
      args = %{"travel_type" => "adventure hiking mountains"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert String.contains?(result, "Found")
      # Should include adventure destinations
      assert String.contains?(result, "Swiss Alps") or String.contains?(result, "Machu Picchu")
    end

    test "returns destinations for city travel type" do
      args = %{"travel_type" => "city culture museums history"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert String.contains?(result, "Found")
      # Should include city destinations
      assert String.contains?(result, "Paris") or String.contains?(result, "Rome")
    end

    test "filters by budget_level" do
      args = %{"travel_type" => "beach", "budget_level" => "luxury"}

      assert {:ok, result} = DestinationTool.execute(args)
      # Should include luxury beach destinations (Maldives)
      assert String.contains?(result, "Maldives")
    end

    test "filters by region_preference" do
      args = %{"travel_type" => "city", "region_preference" => "europe"}

      assert {:ok, result} = DestinationTool.execute(args)
      # Should include European city destinations
      assert String.contains?(result, "Paris") or String.contains?(result, "Rome") or
               String.contains?(result, "Barcelona")
    end

    test "combines budget_level and region_preference filters" do
      args = %{
        "travel_type" => "adventure",
        "budget_level" => "moderate",
        "region_preference" => "americas"
      }

      assert {:ok, result} = DestinationTool.execute(args)
      # Should include Machu Picchu (moderate, americas, adventure)
      assert String.contains?(result, "Machu Picchu")
    end

    test "handles empty travel_type gracefully" do
      args = %{"travel_type" => ""}

      assert {:ok, result} = DestinationTool.execute(args)
      # Should return general recommendations
      assert String.contains?(result, "Found")
      assert String.contains?(result, "matching destinations")
    end

    test "returns error for missing travel_type" do
      args = %{"budget_level" => "luxury"}

      assert {:error, :invalid_arguments} = DestinationTool.execute(args)
    end

    test "each destination has required fields in output" do
      args = %{"travel_type" => "beach"}

      assert {:ok, result} = DestinationTool.execute(args)

      # Check that output contains expected fields
      assert String.contains?(result, "Best for:")
      assert String.contains?(result, "Best time to visit:")
      assert String.contains?(result, "Highlights:")
      assert String.contains?(result, "Region:")
      assert String.contains?(result, "Budget:")
    end
  end

  describe "to_openai_tool/1" do
    test "converts to OpenAI function format" do
      tool = ToolBehaviour.to_openai_tool(DestinationTool)

      assert tool.type == "function"
      assert tool.function.name == "search_destinations"
      assert is_binary(tool.function.description)
      assert is_map(tool.function.parameters)
    end
  end
end
