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
      assert Map.has_key?(params["properties"], "preferences")
    end
  end

  describe "execute/1" do
    test "returns destinations for beach preferences" do
      args = %{"preferences" => "beach relaxation warm weather"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert is_binary(result)
      assert String.contains?(result, "Found")
      assert String.contains?(result, "matching destinations")
      # Should include beach destinations
      assert String.contains?(result, "Bali") or String.contains?(result, "Maldives")
    end

    test "returns destinations for adventure preferences" do
      args = %{"preferences" => "adventure hiking mountains"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert String.contains?(result, "Found")
      # Should include adventure destinations
      assert String.contains?(result, "Swiss Alps") or String.contains?(result, "Machu Picchu")
    end

    test "returns destinations for city preferences" do
      args = %{"preferences" => "city culture museums history"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert String.contains?(result, "Found")
      # Should include city destinations
      assert String.contains?(result, "Paris") or String.contains?(result, "Rome")
    end

    test "handles empty preferences gracefully" do
      args = %{"preferences" => ""}

      assert {:ok, result} = DestinationTool.execute(args)
      # Should return general recommendations
      assert String.contains?(result, "Found")
      assert String.contains?(result, "matching destinations")
    end

    test "each destination has required fields in output" do
      args = %{"preferences" => "beach"}

      assert {:ok, result} = DestinationTool.execute(args)

      # Check that output contains expected fields
      assert String.contains?(result, "Best for:")
      assert String.contains?(result, "Best time to visit:")
      assert String.contains?(result, "Highlights:")
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
