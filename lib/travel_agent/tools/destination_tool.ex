defmodule TravelAgent.Tools.DestinationTool do
  @moduledoc """
  Tool for searching and recommending travel destinations.

  Uses mock destination data to provide recommendations based on user preferences.
  In a production system, this would integrate with a travel API like Amadeus.
  """

  @behaviour TravelAgent.Tools.ToolBehaviour

  @destinations [
    %{
      name: "Bali",
      country: "Indonesia",
      description:
        "Tropical paradise with beautiful beaches, ancient temples, and vibrant culture.",
      best_for: ["beach", "relaxation", "culture", "spa", "honeymoon"],
      best_season: "April to October (dry season)",
      highlights: ["Ubud rice terraces", "Tanah Lot temple", "Seminyak beaches"]
    },
    %{
      name: "Swiss Alps",
      country: "Switzerland",
      description: "Stunning mountain landscapes perfect for skiing and hiking adventures.",
      best_for: ["adventure", "hiking", "skiing", "mountains", "nature"],
      best_season: "December to March (skiing), June to September (hiking)",
      highlights: ["Matterhorn", "Jungfrau region", "Interlaken"]
    },
    %{
      name: "Paris",
      country: "France",
      description: "The City of Light offers world-class art, cuisine, and romantic ambiance.",
      best_for: ["city", "culture", "museums", "history", "romance", "food"],
      best_season: "April to June, September to November",
      highlights: ["Eiffel Tower", "Louvre Museum", "Notre-Dame"]
    },
    %{
      name: "Machu Picchu",
      country: "Peru",
      description: "Ancient Incan citadel set high in the Andes Mountains.",
      best_for: ["adventure", "history", "hiking", "culture", "photography"],
      best_season: "May to October (dry season)",
      highlights: ["Inca Trail", "Sacred Valley", "Cusco"]
    },
    %{
      name: "Maldives",
      country: "Maldives",
      description: "Pristine overwater bungalows and crystal-clear waters.",
      best_for: ["beach", "relaxation", "honeymoon", "diving", "luxury"],
      best_season: "November to April (dry season)",
      highlights: ["Overwater villas", "Coral reefs", "Marine life"]
    },
    %{
      name: "Tokyo",
      country: "Japan",
      description: "Ultra-modern city blending cutting-edge technology with ancient traditions.",
      best_for: ["city", "culture", "food", "technology", "history"],
      best_season: "March to May (cherry blossoms), October to November",
      highlights: ["Shibuya crossing", "Senso-ji temple", "Tsukiji fish market"]
    },
    %{
      name: "Costa Rica",
      country: "Costa Rica",
      description: "Biodiversity hotspot with rainforests, volcanoes, and beautiful beaches.",
      best_for: ["adventure", "nature", "wildlife", "eco-tourism", "beach"],
      best_season: "December to April (dry season)",
      highlights: ["Arenal Volcano", "Manuel Antonio", "Cloud forests"]
    },
    %{
      name: "Rome",
      country: "Italy",
      description: "Eternal City with ancient ruins, Renaissance art, and incredible food.",
      best_for: ["history", "culture", "museums", "food", "architecture"],
      best_season: "April to June, September to October",
      highlights: ["Colosseum", "Vatican", "Roman Forum"]
    },
    %{
      name: "New Zealand",
      country: "New Zealand",
      description: "Dramatic landscapes from fjords to volcanoes, perfect for adventure.",
      best_for: ["adventure", "nature", "hiking", "scenery", "film locations"],
      best_season: "December to February (summer)",
      highlights: ["Milford Sound", "Queenstown", "Rotorua"]
    },
    %{
      name: "Barcelona",
      country: "Spain",
      description: "Vibrant coastal city with unique architecture and lively nightlife.",
      best_for: ["city", "beach", "culture", "architecture", "nightlife", "food"],
      best_season: "May to June, September to October",
      highlights: ["Sagrada Familia", "Park Guell", "La Rambla"]
    }
  ]

  @impl true
  def name, do: "search_destinations"

  @impl true
  def description do
    "Search for travel destination recommendations based on user preferences. " <>
      "Returns a list of destinations matching interests like beach, adventure, city, culture, etc."
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "preferences" => %{
          "type" => "string",
          "description" =>
            "User's travel preferences and interests (e.g., 'beach relaxation', 'adventure hiking', 'city culture museums')"
        }
      },
      "required" => ["preferences"]
    }
  end

  @impl true
  def execute(%{"preferences" => preferences}) do
    preferences_lower = String.downcase(preferences)
    keywords = extract_keywords(preferences_lower)

    matching_destinations =
      @destinations
      |> Enum.map(fn dest ->
        score = calculate_match_score(dest, keywords)
        {dest, score}
      end)
      |> Enum.filter(fn {_dest, score} -> score > 0 end)
      |> Enum.sort_by(fn {_dest, score} -> score end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {dest, _score} -> dest end)

    # If no matches, return top general recommendations
    results =
      if matching_destinations == [] do
        Enum.take(@destinations, 3)
      else
        matching_destinations
      end

    {:ok, format_results_text(results)}
  end

  def execute(_args) do
    {:error, :invalid_arguments}
  end

  # Private functions

  defp extract_keywords(text) do
    text
    |> String.split(~r/[\s,]+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 2))
  end

  defp calculate_match_score(destination, keywords) do
    best_for_text = Enum.join(destination.best_for, " ")
    description_text = String.downcase(destination.description)

    Enum.reduce(keywords, 0, fn keyword, score ->
      cond do
        keyword in destination.best_for -> score + 3
        String.contains?(best_for_text, keyword) -> score + 2
        String.contains?(description_text, keyword) -> score + 1
        true -> score
      end
    end)
  end

  defp format_results_text(destinations) do
    destination_texts =
      destinations
      |> Enum.with_index(1)
      |> Enum.map(fn {dest, index} ->
        highlights = Enum.join(dest.highlights, ", ")

        """
        #{index}. #{dest.name}, #{dest.country}
           #{dest.description}
           Best for: #{Enum.join(dest.best_for, ", ")}
           Best time to visit: #{dest.best_season}
           Highlights: #{highlights}
        """
      end)
      |> Enum.join("\n")

    """
    Found #{length(destinations)} matching destinations:

    #{destination_texts}
    Use this information to provide personalized recommendations to the user.
    """
  end
end
