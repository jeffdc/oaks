defmodule Oaks.Storage.S3 do
  @moduledoc """
  Stores species photos in the private `oaks-images` bucket and invalidates
  their paths on the CloudFront distribution that serves them (infra/).

  Signs in as `oaks-images-upload`, whose keys are the `:access_key_id` and
  `:secret_access_key` of `config :oaks, :images` (config/runtime.exs). They
  are passed on every request, so ex_aws never falls back to other AWS
  credentials in the environment (Litestream's). That user can put, delete
  and list objects and create and get invalidations, but not read objects:
  the app never reads photos back.

  S3 goes through ex_aws (on Req); CloudFront through Req with its SigV4
  signing, as ex_aws has no CloudFront module. `:req_options` in the config
  are merged into both (tests route them to `Req.Test`).

  Ported from gallformers' `Gallformers.Storage.S3` and `.Images`, which have
  no invalidation.
  """

  @behaviour Oaks.Storage.Adapter

  import SweetXml, only: [sigil_x: 2]

  alias Oaks.Storage.Images

  @cloudfront_url "https://cloudfront.amazonaws.com/2020-05-31"
  # Paths are never rewritten (Oaks.Storage.Images), so browsers may keep a
  # file as long as the CDN does.
  @cache_control "public, max-age=31536000, immutable"

  @impl true
  def put(path, data, content_type) do
    bucket()
    |> ExAws.S3.put_object(path, data, content_type: content_type, cache_control: @cache_control)
    |> request()
    |> ok()
  end

  @impl true
  def delete(path) do
    # 204 whether or not the object existed. In the versioned bucket this
    # adds a delete marker; the lifecycle removes the old version later.
    bucket() |> ExAws.S3.delete_object(path) |> request() |> ok()
  end

  @impl true
  def list(prefix), do: list(prefix, nil, [])

  defp list(prefix, token, acc) do
    opts = [prefix: prefix] ++ if(token, do: [continuation_token: token], else: [])

    case bucket() |> ExAws.S3.list_objects_v2(opts) |> request() do
      {:ok, %{body: body}} ->
        acc = acc ++ Enum.map(body.contents, & &1.key)

        case body do
          %{is_truncated: "true", next_continuation_token: next} when next != "" ->
            list(prefix, next, acc)

          _ ->
            {:ok, acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def create_invalidation(paths, caller_reference) do
    items = Enum.map_join(paths, &"<Path>/#{xml_escape(&1)}</Path>")

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <InvalidationBatch xmlns="http://cloudfront.amazonaws.com/doc/2020-05-31/">\
    <CallerReference>#{xml_escape(caller_reference)}</CallerReference>\
    <Paths><Quantity>#{length(paths)}</Quantity><Items>#{items}</Items></Paths>\
    </InvalidationBatch>
    """

    with {:ok, req} <- cloudfront(),
         {:ok, xml} <-
           cloudfront_request(req,
             method: :post,
             url: "/distribution/#{distribution_id()}/invalidation",
             headers: [content_type: "text/xml"],
             body: body
           ) do
      {:ok, SweetXml.xpath(xml, ~x"//Invalidation/Id/text()"s)}
    end
  end

  @impl true
  def invalidation_status(invalidation_id) do
    with {:ok, req} <- cloudfront(),
         {:ok, xml} <-
           cloudfront_request(req,
             method: :get,
             url: "/distribution/#{distribution_id()}/invalidation/#{URI.encode(invalidation_id)}"
           ) do
      case SweetXml.xpath(xml, ~x"//Invalidation/Status/text()"s) do
        "Completed" -> {:ok, :completed}
        "InProgress" -> {:ok, :in_progress}
        other -> {:error, {:unexpected_status, other}}
      end
    end
  end

  defp request(operation) do
    case credentials() do
      {:ok, keys} ->
        ExAws.request(
          operation,
          keys ++ [region: "us-east-1", virtual_host: true, http_opts: req_options()]
        )

      error ->
        error
    end
  end

  defp ok({:ok, _response}), do: :ok
  defp ok({:error, reason}), do: {:error, reason}

  defp cloudfront do
    with {:ok, keys} <- credentials() do
      sigv4 = keys ++ [service: :cloudfront, region: "us-east-1"]
      {:ok, Req.new([base_url: @cloudfront_url, aws_sigv4: sigv4] ++ req_options())}
    end
  end

  defp cloudfront_request(req, opts) do
    case Req.request(req, opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, error_code(body)}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp error_code(body) when is_binary(body) and body != "" do
    case body |> SweetXml.parse(quiet: true) |> SweetXml.xpath(~x"//Error/Code/text()"s) do
      "" -> nil
      code -> code
    end
  catch
    # Not XML (a proxy's HTML error page, say).
    :exit, _ -> nil
  end

  defp error_code(_body), do: nil

  defp credentials do
    case {Images.config(:access_key_id), Images.config(:secret_access_key)} do
      {id, secret} when is_binary(id) and id != "" and is_binary(secret) and secret != "" ->
        {:ok, [access_key_id: id, secret_access_key: secret]}

      _ ->
        {:error, :missing_credentials}
    end
  end

  defp bucket, do: Images.config(:bucket)
  defp distribution_id, do: Images.config(:distribution_id)
  defp req_options, do: Images.config(:req_options) || []

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
