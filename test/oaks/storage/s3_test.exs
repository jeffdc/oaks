defmodule Oaks.Storage.S3Test do
  # S3 and CloudFront are stubbed with Req.Test (config/test.exs routes both
  # there, with fake keys); the application env is changed in one test.
  use ExUnit.Case, async: false

  alias Oaks.Storage.S3

  @path "species/7/7_1764000000000_0a1b2c3d4e_original.jpg"

  describe "put/3" do
    test "PUTs the object to the bucket, signed, with its type and a long cache life" do
      Req.Test.expect(S3, fn conn ->
        assert conn.method == "PUT"
        assert conn.host == "oaks-images.s3.amazonaws.com"
        assert conn.request_path == "/" <> @path
        assert header(conn, "content-type") == "image/jpeg"
        assert header(conn, "cache-control") == "public, max-age=31536000, immutable"
        assert header(conn, "authorization") =~ ~r"\AAWS4-HMAC-SHA256 Credential=AKIATEST/"
        assert header(conn, "authorization") =~ "/us-east-1/s3/aws4_request"
        assert {:ok, "jpeg bytes", _} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert :ok = S3.put(@path, "jpeg bytes", "image/jpeg")
    end

    test "returns S3's refusal" do
      Req.Test.expect(S3, &Plug.Conn.send_resp(&1, 403, s3_error("AccessDenied")))
      assert {:error, {:http_error, 403, _}} = S3.put(@path, "x", "image/jpeg")
    end

    @tag :capture_log
    test "returns a network failure" do
      Req.Test.expect(S3, &Req.Test.transport_error(&1, :timeout))
      assert {:error, _} = S3.put(@path, "x", "image/jpeg")
    end

    test "makes no request without keys" do
      config = Application.fetch_env!(:oaks, :images)
      Application.put_env(:oaks, :images, Keyword.delete(config, :secret_access_key))
      on_exit(fn -> Application.put_env(:oaks, :images, config) end)

      Req.Test.stub(S3, fn _conn -> flunk("no request without keys") end)

      assert {:error, :missing_credentials} = S3.put(@path, "x", "image/jpeg")
      assert {:error, :missing_credentials} = S3.create_invalidation([@path], "ref")
    end
  end

  describe "delete/1" do
    test "DELETEs the object; S3's 204 is the same whether or not it existed" do
      Req.Test.expect(S3, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/" <> @path
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = S3.delete(@path)
    end

    test "returns S3's refusal" do
      Req.Test.expect(S3, &Plug.Conn.send_resp(&1, 403, s3_error("AccessDenied")))
      assert {:error, {:http_error, 403, _}} = S3.delete(@path)
    end
  end

  describe "list/1" do
    test "follows continuation tokens through every page" do
      Req.Test.expect(S3, 2, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["list-type"] == "2"
        assert conn.query_params["prefix"] == "species/7/"

        body =
          case conn.query_params["continuation-token"] do
            nil -> list_page(["species/7/a_original.jpg", "species/7/a_small.jpg"], "page2")
            "page2" -> list_page(["species/7/b_original.jpg"], nil)
          end

        Plug.Conn.send_resp(conn, 200, body)
      end)

      assert {:ok,
              ["species/7/a_original.jpg", "species/7/a_small.jpg", "species/7/b_original.jpg"]} =
               S3.list("species/7/")
    end

    test "returns a failure on any page" do
      Req.Test.expect(S3, &Plug.Conn.send_resp(&1, 200, list_page(["a"], "page2")))
      Req.Test.expect(S3, &Plug.Conn.send_resp(&1, 500, s3_error("InternalError")))

      assert {:error, {:http_error, 500, _}} = S3.list("species/")
    end
  end

  describe "create_invalidation/2" do
    test "POSTs the paths and caller reference to the distribution and returns the ID" do
      Req.Test.expect(S3, fn conn ->
        assert conn.method == "POST"
        assert conn.host == "cloudfront.amazonaws.com"
        assert conn.request_path == "/2020-05-31/distribution/E1GM6FGGDJPT7E/invalidation"
        assert header(conn, "authorization") =~ "/us-east-1/cloudfront/aws4_request"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ "<CallerReference>cleanup-3</CallerReference>"
        assert body =~ "<Quantity>2</Quantity>"
        assert body =~ "<Path>/#{@path}</Path><Path>/species/7/x_small.jpg</Path>"

        Plug.Conn.send_resp(conn, 201, invalidation("I2J0I21PCUYOIK", "InProgress"))
      end)

      assert {:ok, "I2J0I21PCUYOIK"} =
               S3.create_invalidation([@path, "species/7/x_small.jpg"], "cleanup-3")
    end

    test "returns CloudFront's error code" do
      Req.Test.expect(S3, fn conn ->
        Plug.Conn.send_resp(conn, 409, cloudfront_error("InvalidationBatchAlreadyExists"))
      end)

      assert {:error, {:http_error, 409, "InvalidationBatchAlreadyExists"}} =
               S3.create_invalidation([@path], "cleanup-3")
    end

    test "returns a network failure" do
      Req.Test.expect(S3, &Req.Test.transport_error(&1, :econnrefused))

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               S3.create_invalidation([@path], "ref")
    end
  end

  describe "invalidation_status/1" do
    test "reads the invalidation's status" do
      Req.Test.expect(S3, 2, fn conn ->
        assert conn.method == "GET"

        assert conn.request_path ==
                 "/2020-05-31/distribution/E1GM6FGGDJPT7E/invalidation/I2J0I21PCUYOIK"

        status = if Process.get(:checked), do: "Completed", else: "InProgress"
        Process.put(:checked, true)
        Plug.Conn.send_resp(conn, 200, invalidation("I2J0I21PCUYOIK", status))
      end)

      assert {:ok, :in_progress} = S3.invalidation_status("I2J0I21PCUYOIK")
      assert {:ok, :completed} = S3.invalidation_status("I2J0I21PCUYOIK")
    end

    test "returns CloudFront's error code, even when the body isn't XML" do
      Req.Test.expect(S3, &Plug.Conn.send_resp(&1, 404, cloudfront_error("NoSuchInvalidation")))
      Req.Test.expect(S3, &Plug.Conn.send_resp(&1, 502, "<html>Bad gateway"))

      assert {:error, {:http_error, 404, "NoSuchInvalidation"}} = S3.invalidation_status("nope")
      assert {:error, {:http_error, 502, nil}} = S3.invalidation_status("nope")
    end
  end

  defp header(conn, name), do: conn |> Plug.Conn.get_req_header(name) |> List.first()

  defp list_page(keys, next_token) do
    contents = Enum.map_join(keys, &"<Contents><Key>#{&1}</Key><Size>1</Size></Contents>")

    next =
      if next_token,
        do:
          "<IsTruncated>true</IsTruncated><NextContinuationToken>#{next_token}</NextContinuationToken>",
        else: "<IsTruncated>false</IsTruncated>"

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">\
    <Name>oaks-images</Name>#{contents}#{next}</ListBucketResult>
    """
  end

  defp s3_error(code), do: "<Error><Code>#{code}</Code><Message>no</Message></Error>"

  defp invalidation(id, status) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Invalidation xmlns="http://cloudfront.amazonaws.com/doc/2020-05-31/">\
    <Id>#{id}</Id><Status>#{status}</Status><CreateTime>2026-11-24T20:00:00Z</CreateTime>\
    </Invalidation>
    """
  end

  defp cloudfront_error(code) do
    """
    <?xml version="1.0"?>
    <ErrorResponse xmlns="http://cloudfront.amazonaws.com/doc/2020-05-31/">\
    <Error><Type>Sender</Type><Code>#{code}</Code><Message>no</Message></Error>\
    </ErrorResponse>
    """
  end
end
