defmodule TravelAgent.Tools.ToolBehaviour do
  @moduledoc """
  Behaviour defining the interface for agent tools.

  Tools enable the LLM to take actions like searching destinations,
  looking up information, etc.
  """

  @doc """
  Returns the tool name as used in OpenAI function calling.
  """
  @callback name() :: String.t()

  @doc """
  Returns a description of what the tool does.
  """
  @callback description() :: String.t()

  @doc """
  Returns the JSON Schema for the tool's parameters.
  """
  @callback parameters() :: map()

  @doc """
  Executes the tool with the given arguments.

  ## Parameters
  - `args` - Map of arguments matching the parameters schema

  ## Returns
  - `{:ok, result}` - Tool execution succeeded
  - `{:error, reason}` - Tool execution failed
  """
  @callback execute(args :: map()) :: {:ok, String.t()} | {:error, term()}

  @doc """
  Converts the tool to OpenAI function calling format.
  """
  def to_openai_tool(module) do
    %{
      type: "function",
      function: %{
        name: module.name(),
        description: module.description(),
        parameters: module.parameters()
      }
    }
  end
end
