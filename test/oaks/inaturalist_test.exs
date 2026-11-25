defmodule Oaks.INaturalistTest do
  use ExUnit.Case, async: false

  import Oaks.ImagesFixtures

  alias Oaks.INaturalist
  alias Oaks.INaturalist.{Observation, Photo}

  doctest Oaks.INaturalist

  @moduletag :capture_log

  describe "map_license/1" do
    test "maps iNat's license codes" do
      assert INaturalist.map_license("cc0") == "Public Domain / CC0"
      assert INaturalist.map_license("cc-by") == "CC-BY"
      assert INaturalist.map_license("cc-by-sa") == "CC-BY-SA"
      assert INaturalist.map_license("cc-by-nc") == "CC-BY-NC"
      assert INaturalist.map_license("cc-by-nc-sa") == "CC-BY-NC-SA"
      assert INaturalist.map_license("cc-by-nd") == "CC-BY-ND"
      assert INaturalist.map_license("CC-BY-NC-ND") == "CC-BY-NC-ND"
    end

    test "maps no license, or one it doesn't know, to All Rights Reserved" do
      assert INaturalist.map_license(nil) == "All Rights Reserved"
      assert INaturalist.map_license("gpl") == "All Rights Reserved"
      assert INaturalist.map_license("") == "All Rights Reserved"
    end
  end

  describe "parse_observation_id/1" do
    test "takes an observation URL, with or without www, query or fragment" do
      for url <- [
            "https://www.inaturalist.org/observations/12345",
            "https://inaturalist.org/observations/12345",
            "http://www.inaturalist.org/observations/12345?locale=en",
            "https://www.inaturalist.org/observations/12345#activity",
            "  https://www.inaturalist.org/observations/12345/  "
          ] do
        assert INaturalist.parse_observation_id(url) == {:ok, "12345"}, url
      end
    end

    test "takes a bare ID" do
      assert INaturalist.parse_observation_id(" 12345 ") == {:ok, "12345"}
    end

    test "refuses anything else" do
      for input <- [
            "",
            "not-a-url",
            "https://example.com/observations/123",
            "https://www.inaturalist.org/observations/123abc",
            "https://evil.example/?u=https://www.inaturalist.org/observations/1",
            nil
          ] do
        assert INaturalist.parse_observation_id(input) == {:error, :invalid_input}, inspect(input)
      end
    end
  end

  describe "fetch_observation/1" do
    test "fetches and parses an observation and its photos" do
      cc = inat_photo_json(%{license_code: "cc-by"})
      arr = inat_photo_json(%{license_code: nil})
      json = observation_json(%{photos: [cc, arr]})
      %{"results" => [%{"id" => id}]} = json
      stub_inat(json, test_pid: self())

      assert {:ok, %Observation{} = observation} =
               INaturalist.fetch_observation("https://www.inaturalist.org/observations/#{id}")

      assert_received {:inat_request, path}
      assert path == "/v1/observations/#{id}"

      assert observation.id == id
      assert observation.url == "https://www.inaturalist.org/observations/#{id}"
      assert observation.observer_login == "janedoe"
      assert observation.observer_name == "Jane Doe"
      assert observation.taxon_name == "Quercus alba"
      assert observation.observed_on == ~D[2026-05-04]
      assert observation.place_guess == "Blue Ridge, VA"
      assert observation.quality_grade == "research"

      assert [%Photo{} = open, %Photo{} = reserved] = observation.photos
      assert open.id == cc["id"]
      assert open.mapped_license == "CC-BY"
      refute open.all_rights_reserved?
      assert open.thumbnail_url =~ ~r"/photos/#{cc["id"]}/medium\.jpg\z"
      assert open.original_url =~ ~r"/photos/#{cc["id"]}/original\.jpg\z"
      assert reserved.mapped_license == "All Rights Reserved"
      assert reserved.all_rights_reserved?
    end

    test "sends the app's user agent, naming no person" do
      json = observation_json()
      %{"results" => [%{"id" => id}]} = json

      Req.Test.stub(INaturalist, fn conn ->
        assert Plug.Conn.get_req_header(conn, "user-agent") == [
                 "OakCompendium/1.0 (oakcompendium.org)"
               ]

        Req.Test.json(conn, json)
      end)

      assert {:ok, _} = INaturalist.fetch_observation("#{id}")
    end

    test "reports a missing observation, bad input and iNat being down" do
      stub_inat([])
      assert INaturalist.fetch_observation("999") == {:error, :not_found}
      assert INaturalist.fetch_observation("nope") == {:error, :invalid_input}

      Req.Test.stub(INaturalist, &Plug.Conn.send_resp(&1, 503, ""))
      assert INaturalist.fetch_observation("999") == {:error, {:http_error, 503}}

      Req.Test.stub(INaturalist, &Req.Test.transport_error(&1, :econnrefused))

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               INaturalist.fetch_observation("999")
    end

    test "refuses a response that isn't an observation" do
      assert INaturalist.parse_observation_response(%{"results" => [%{"id" => "x"}]}) ==
               {:error, :invalid_response}

      assert INaturalist.parse_observation_response(%{}) == {:error, :invalid_response}
    end
  end

  describe "download_photo/1" do
    test "downloads from iNaturalist's photo hosts only" do
      stub_inat([], bytes: "jpeg bytes")

      assert INaturalist.download_photo(
               "https://inaturalist-open-data.s3.amazonaws.com/photos/1/original.jpg"
             ) == {:ok, "jpeg bytes"}

      assert INaturalist.download_photo("https://static.inaturalist.org/photos/1/original.jpg") ==
               {:ok, "jpeg bytes"}

      for url <- [
            "http://static.inaturalist.org/photos/1/original.jpg",
            "https://example.com/photos/1/original.jpg",
            "https://static.inaturalist.org.evil.example/photos/1/original.jpg",
            "file:///etc/passwd"
          ] do
        assert INaturalist.download_photo(url) == {:error, :invalid_url}, url
      end
    end

    test "reports HTTP errors" do
      stub_inat([], photo_status: %{1 => 404})

      assert INaturalist.download_photo("https://static.inaturalist.org/photos/1/original.jpg") ==
               {:error, {:http_error, 404}}
    end
  end

  describe "format_creator/2" do
    test "credits the login, then the name when there is one" do
      assert INaturalist.format_creator("janedoe", "Jane Doe") == "janedoe - Jane Doe"
      assert INaturalist.format_creator("janedoe", nil) == "janedoe"
      assert INaturalist.format_creator("janedoe", "  ") == "janedoe"
      assert INaturalist.format_creator("janedoe", "janedoe") == "janedoe"
    end
  end
end
