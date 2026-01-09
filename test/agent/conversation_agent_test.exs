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
end
