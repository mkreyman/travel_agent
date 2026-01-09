defmodule TravelAgent.Agent.ConversationAgentTest do
  use ExUnit.Case, async: true

  import Mox

  alias TravelAgent.Agent.ConversationAgent
  alias TravelAgent.LLM.MockClient

  setup :verify_on_exit!

  # Helper to start agent and allow mock access
  defp start_agent(opts \\ []) do
    {:ok, agent} = ConversationAgent.start_link(opts)
    Mox.allow(MockClient, self(), agent)
    {:ok, agent}
  end

  describe "start_link/1" do
    test "starts a conversation agent" do
      assert {:ok, pid} = ConversationAgent.start_link()
      assert Process.alive?(pid)
    end

    test "accepts custom system prompt" do
      expect(MockClient, :chat, fn messages, _opts ->
        assert Enum.any?(messages, fn m ->
                 m.role == "system" && String.contains?(m.content, "custom")
               end)

        {:ok, "response"}
      end)

      {:ok, agent} = start_agent(system_prompt: "You are a custom assistant.")
      ConversationAgent.chat(agent, "test")
    end
  end

  describe "chat/2" do
    test "sends message and returns response" do
      expect(MockClient, :chat, fn messages, _opts ->
        assert Enum.any?(messages, fn m -> m.role == "user" && m.content == "Hello" end)
        {:ok, "Hi there!"}
      end)

      {:ok, agent} = start_agent()
      assert {:ok, "Hi there!"} = ConversationAgent.chat(agent, "Hello")
    end

    test "maintains conversation history" do
      expect(MockClient, :chat, fn _messages, _opts -> {:ok, "First response"} end)

      expect(MockClient, :chat, fn messages, _opts ->
        # Should include previous exchange
        assert length(messages) >= 3
        {:ok, "Second response"}
      end)

      {:ok, agent} = start_agent()
      ConversationAgent.chat(agent, "First message")
      ConversationAgent.chat(agent, "Second message")
    end

    test "returns error on LLM failure" do
      expect(MockClient, :chat, fn _messages, _opts -> {:error, :timeout} end)

      {:ok, agent} = start_agent()
      assert {:error, :timeout} = ConversationAgent.chat(agent, "Hello")
    end
  end

  describe "get_history/1" do
    test "returns empty history for new agent" do
      {:ok, agent} = ConversationAgent.start_link()
      history = ConversationAgent.get_history(agent)

      # Should only have system message
      assert length(history) == 1
      assert hd(history).role == "system"
    end

    test "returns messages after conversation" do
      expect(MockClient, :chat, fn _messages, _opts -> {:ok, "Response"} end)

      {:ok, agent} = start_agent()
      ConversationAgent.chat(agent, "Hello")

      history = ConversationAgent.get_history(agent)
      assert length(history) == 3
    end
  end

  describe "clear_history/1" do
    test "resets to only system prompt" do
      expect(MockClient, :chat, fn _messages, _opts -> {:ok, "Response"} end)

      {:ok, agent} = start_agent()
      ConversationAgent.chat(agent, "Hello")
      ConversationAgent.clear_history(agent)

      history = ConversationAgent.get_history(agent)
      assert length(history) == 1
      assert hd(history).role == "system"
    end
  end

  describe "tool execution" do
    alias TravelAgent.Tools.DestinationTool

    test "chat_with_tools/2 handles tool calls" do
      # First call returns a tool call request
      expect(MockClient, :chat_with_tools, fn _messages, _tools, _opts ->
        {:ok,
         %{
           "content" => nil,
           "tool_calls" => [
             %{
               "id" => "call_123",
               "type" => "function",
               "function" => %{
                 "name" => "search_destinations",
                 "arguments" => ~s({"preferences": "beach relaxation"})
               }
             }
           ]
         }}
      end)

      # Second call returns the final response after tool result
      expect(MockClient, :chat_with_tools, fn messages, _tools, _opts ->
        # Should include tool result
        assert Enum.any?(messages, fn m -> m[:role] == "tool" end)
        {:ok, %{"content" => "Based on your preferences, I recommend Bali!"}}
      end)

      {:ok, agent} = start_agent(tools: [DestinationTool])

      assert {:ok, response} =
               ConversationAgent.chat_with_tools(agent, "Find me a beach destination")

      assert String.contains?(response, "Bali")
    end

    test "chat_with_tools/2 returns regular response when no tool call" do
      expect(MockClient, :chat_with_tools, fn _messages, _tools, _opts ->
        {:ok, %{"content" => "Hello! How can I help you plan your trip?"}}
      end)

      {:ok, agent} = start_agent(tools: [DestinationTool])

      assert {:ok, "Hello! How can I help you plan your trip?"} =
               ConversationAgent.chat_with_tools(agent, "Hi")
    end

    test "handles unknown tool gracefully" do
      expect(MockClient, :chat_with_tools, fn _messages, _tools, _opts ->
        {:ok,
         %{
           "content" => nil,
           "tool_calls" => [
             %{
               "id" => "call_456",
               "type" => "function",
               "function" => %{
                 "name" => "unknown_tool",
                 "arguments" => "{}"
               }
             }
           ]
         }}
      end)

      # Should call again with error message
      expect(MockClient, :chat_with_tools, fn messages, _tools, _opts ->
        tool_result = Enum.find(messages, &(&1[:role] == "tool"))
        assert tool_result
        assert String.contains?(tool_result.content, "error")
        {:ok, %{"content" => "Sorry, I couldn't complete that action."}}
      end)

      {:ok, agent} = start_agent(tools: [DestinationTool])
      assert {:ok, _response} = ConversationAgent.chat_with_tools(agent, "Do something")
    end

    test "returns error after max tool iterations exceeded" do
      # Set up repeated tool calls to exceed the limit
      expect(MockClient, :chat_with_tools, 5, fn _messages, _tools, _opts ->
        {:ok,
         %{
           "content" => nil,
           "tool_calls" => [
             %{
               "id" => "call_#{System.unique_integer([:positive])}",
               "type" => "function",
               "function" => %{
                 "name" => "search_destinations",
                 "arguments" => ~s({"travel_type": "beach"})
               }
             }
           ]
         }}
      end)

      {:ok, agent} = start_agent(tools: [DestinationTool])

      assert {:error, :max_tool_iterations_exceeded} =
               ConversationAgent.chat_with_tools(agent, "Keep searching")
    end
  end

  describe "context trimming" do
    test "trims context when exceeding max messages" do
      # Simulate 25 exchanges (50 messages + system = 51 total)
      # After trimming, should have system + last 19 messages = 20 total
      for i <- 1..25 do
        expect(MockClient, :chat, fn messages, _opts ->
          # After the first ~20 messages, we should see trimming in action
          # The total messages should never exceed 21 (system + 20 context)
          if i > 10 do
            assert length(messages) <= 21,
                   "Expected max 21 messages but got #{length(messages)}"
          end

          {:ok, "Response #{i}"}
        end)
      end

      {:ok, agent} = start_agent()

      for i <- 1..25 do
        {:ok, _} = ConversationAgent.chat(agent, "Message #{i}")
      end
    end
  end
end
