defmodule TravelAgentWeb.ErrorHTML do
  @moduledoc """
  Error page templates.
  """

  use TravelAgentWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
