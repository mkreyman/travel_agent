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
      # Should return JSON with destinations
      assert {:ok, data} = Jason.decode(result)
      assert is_list(data["destinations"])
      assert data["destinations"] != []
    end

    test "returns destinations for adventure preferences" do
      args = %{"preferences" => "adventure hiking mountains"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert {:ok, data} = Jason.decode(result)
      assert is_list(data["destinations"])
    end

    test "returns destinations for city preferences" do
      args = %{"preferences" => "city culture museums history"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert {:ok, data} = Jason.decode(result)
      assert is_list(data["destinations"])
    end

    test "handles empty preferences gracefully" do
      args = %{"preferences" => ""}

      assert {:ok, result} = DestinationTool.execute(args)
      assert {:ok, data} = Jason.decode(result)
      # Should return general recommendations
      assert is_list(data["destinations"])
    end

    test "each destination has required fields" do
      args = %{"preferences" => "any"}

      assert {:ok, result} = DestinationTool.execute(args)
      assert {:ok, data} = Jason.decode(result)

      Enum.each(data["destinations"], fn dest ->
        assert Map.has_key?(dest, "name")
        assert Map.has_key?(dest, "country")
        assert Map.has_key?(dest, "description")
        assert Map.has_key?(dest, "best_for")
        assert Map.has_key?(dest, "best_season")
      end)
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
