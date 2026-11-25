defmodule Oaks.INaturalist do
  @moduledoc """
  The iNaturalist API client species photos are imported with: fetching an
  observation and its photos, downloading a photo, and mapping iNat's license
  codes and observer names to the values an image stores.

  Every request names the app, never a person, and goes through the
  `:req_options` of `config :oaks, Oaks.INaturalist` (tests route them to a
  `Req.Test` stub, so no test reaches iNaturalist).

  Ported from gallformers' `Gallformers.INaturalist`, without the places and
  observation field lookups oaks has no use for.
  """

  require Logger

  alias Oaks.INaturalist.{Observation, Photo}
  alias Oaks.Licenses

  @api_base "https://api.inaturalist.org/v1"
  @user_agent "OakCompendium/1.0 (oakcompendium.org)"

  @license_map %{
    "cc0" => "Public Domain / CC0",
    "cc-by" => "CC-BY",
    "cc-by-sa" => "CC-BY-SA",
    "cc-by-nc" => "CC-BY-NC",
    "cc-by-nc-sa" => "CC-BY-NC-SA",
    "cc-by-nd" => "CC-BY-ND",
    "cc-by-nc-nd" => "CC-BY-NC-ND"
  }

  @observation_url_pattern ~r{\Ahttps?://(?:www\.)?inaturalist\.org/observations/(\d+)(?:[/?#]|\z)}

  # Photos are downloaded only from iNaturalist's own photo hosts: a photo
  # URL is stored with its import attempt and fetched later by a worker, so
  # nothing else should ever be fetched through it.
  @photo_hosts ["inaturalist-open-data.s3.amazonaws.com", "static.inaturalist.org"]

  @doc """
  The license an image stores for an iNat `license_code`. No code is iNat's
  way of saying All Rights Reserved; a code this list doesn't know is stored
  as All Rights Reserved too (no license we know of was given). Either can be
  imported only with the creator's permission (`Oaks.Licenses`).
  """
  @spec map_license(String.t() | nil) :: String.t()
  def map_license(code) when is_binary(code),
    do: Map.get(@license_map, String.downcase(code), Licenses.all_rights_reserved())

  def map_license(_code), do: Licenses.all_rights_reserved()

  @doc """
  Whether an iNat `license_code` is one this client doesn't know: not a
  Creative Commons code and not the missing (or blank) code that means All
  Rights Reserved. The editor sees such a photo as "No license given"
  (Jeff, 2026-11-25).
  """
  @spec unrecognized_license?(String.t() | nil) :: boolean()
  def unrecognized_license?(code) when is_binary(code),
    do: String.trim(code) != "" and not Map.has_key?(@license_map, String.downcase(code))

  def unrecognized_license?(_code), do: false

  @doc """
  The observation ID in an iNaturalist observation URL or a bare ID.

      iex> Oaks.INaturalist.parse_observation_id("https://www.inaturalist.org/observations/12345?locale=en")
      {:ok, "12345"}
  """
  @spec parse_observation_id(String.t()) :: {:ok, String.t()} | {:error, :invalid_input}
  def parse_observation_id(input) when is_binary(input) do
    input = String.trim(input)

    cond do
      Regex.match?(~r/\A\d+\z/, input) ->
        {:ok, input}

      match = Regex.run(@observation_url_pattern, input) ->
        {:ok, Enum.at(match, 1)}

      true ->
        {:error, :invalid_input}
    end
  end

  def parse_observation_id(_input), do: {:error, :invalid_input}

  @doc """
  Fetches an iNaturalist observation by URL or ID.

  Errors: `:invalid_input`, `:not_found`, `:invalid_response`,
  `{:http_error, status}`, or the transport's exception.
  """
  @spec fetch_observation(String.t()) :: {:ok, Observation.t()} | {:error, term()}
  def fetch_observation(input) do
    with {:ok, id} <- parse_observation_id(input),
         {:ok, json} <- get_json("observations/#{id}") do
      parse_observation_response(json)
    end
  end

  @doc """
  Downloads a photo's bytes from one of iNaturalist's photo hosts.

  Errors: `:invalid_url` for any other URL, `{:http_error, status}`, or the
  transport's exception.
  """
  @spec download_photo(String.t()) :: {:ok, binary()} | {:error, term()}
  def download_photo(url) when is_binary(url) do
    if photo_url?(url) do
      case Req.get(url, request_options()) do
        {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) and body != "" ->
          {:ok, body}

        {:ok, %Req.Response{status: status}} ->
          {:error, {:http_error, status}}

        {:error, exception} ->
          {:error, exception}
      end
    else
      {:error, :invalid_url}
    end
  end

  @doc "Whether `url` is on one of iNaturalist's photo hosts, over HTTPS."
  @spec photo_url?(String.t()) :: boolean()
  def photo_url?(url) when is_binary(url) do
    match?(%URI{scheme: "https", host: host} when host in @photo_hosts, URI.parse(url))
  end

  @doc "Parses the API's response for one observation."
  @spec parse_observation_response(map()) ::
          {:ok, Observation.t()} | {:error, :not_found | :invalid_response}
  def parse_observation_response(%{"results" => [%{"id" => id} = raw | _]}) when is_integer(id) do
    {:ok,
     %Observation{
       id: id,
       taxon_id: get_in(raw, ["taxon", "id"]),
       taxon_name: get_in(raw, ["taxon", "name"]),
       observer_login: get_in(raw, ["user", "login"]),
       observer_name: get_in(raw, ["user", "name"]),
       url: "https://www.inaturalist.org/observations/#{id}",
       observed_on: observed_on(raw["observed_on"]),
       place_guess: raw["place_guess"],
       quality_grade: raw["quality_grade"],
       photos:
         for(%{"id" => photo_id} = p <- raw["photos"] || [], is_integer(photo_id), do: photo(p))
     }}
  end

  def parse_observation_response(%{"results" => []}), do: {:error, :not_found}
  def parse_observation_response(_json), do: {:error, :invalid_response}

  defp photo(raw) do
    license = map_license(raw["license_code"])

    %Photo{
      id: raw["id"],
      thumbnail_url: photo_size_url(raw["url"], "medium"),
      original_url: photo_size_url(raw["url"], "original"),
      license_code: raw["license_code"],
      mapped_license: license,
      needs_permission?: Licenses.needs_permission?(license),
      unrecognized_license?: unrecognized_license?(raw["license_code"])
    }
  end

  defp observed_on(text) when is_binary(text) do
    case Date.from_iso8601(String.slice(text, 0, 10)) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp observed_on(_text), do: nil

  @doc """
  The creator an image credits: the observer's login, followed by their
  display name when they have one that differs from it.

      iex> Oaks.INaturalist.format_creator("janedoe", "Jane Doe")
      "janedoe - Jane Doe"
  """
  @spec format_creator(String.t(), String.t() | nil) :: String.t()
  def format_creator(login, name) do
    case name && String.trim(name) do
      blank when blank in [nil, "", login] -> login
      name -> "#{login} - #{name}"
    end
  end

  # The API gives each photo's "square" URL; other sizes swap the name.
  defp photo_size_url(url, size) when is_binary(url) do
    String.replace(url, ~r{/square\.(jpe?g|png|webp)(?=\?|\z)}i, "/#{size}.\\1")
  end

  defp photo_size_url(_url, _size), do: nil

  defp get_json(path) do
    case Req.get("#{@api_base}/#{path}", request_options()) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 200}} ->
        {:error, :invalid_response}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("iNaturalist API returned #{status} for #{path}")
        {:error, {:http_error, status}}

      {:error, exception} ->
        Logger.warning(
          "iNaturalist API request failed for #{path}: #{Exception.message(exception)}"
        )

        {:error, exception}
    end
  end

  defp request_options do
    [headers: [{"user-agent", @user_agent}], receive_timeout: 30_000] ++
      Keyword.get(Application.get_env(:oaks, __MODULE__, []), :req_options, [])
  end
end
