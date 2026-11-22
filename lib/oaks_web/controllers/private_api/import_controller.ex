defmodule OaksWeb.PrivateAPI.ImportController do
  @moduledoc """
  `POST /api/private/v1/import`: bulk changes for agents with a
  `packages:submit` token (item f8f5). `Oaks.Import` does the work;
  `docs/import.md` is the producer's guide.

  Every import is two requests with the same body bytes:

    1. `POST /api/private/v1/import?dry_run=true` validates the body,
       reports what would change, writes nothing, and returns a
       `dry_run_token` (`OaksWeb.ImportDryRunToken`).
    2. `POST /api/private/v1/import` with the header
       `dry-run-token: <token>` applies it.

  The flag and the token stay outside the body, so the body that is hashed
  is the body that applies. `OaksWeb.BodyDigest` hashes the raw bytes as
  `Plug.Parsers` reads them.

  Status codes: 200 for a dry run, an apply or an import already applied;
  415 for a body that isn't `application/json`; 422 with `errors` for
  records that fail; 428 for a missing or unusable dry-run token; 409 when
  the database changed since the dry run or an `import_id` was applied with
  another body. Bad JSON (400) and bodies over 8 MB (413) are refused by
  `Plug.Parsers` before this controller runs.
  """
  use OaksWeb, :controller

  import OaksWeb.Plugs.ApiToken, only: [require_api_scope: 2]

  alias Oaks.Import
  alias OaksWeb.ImportDryRunToken
  alias OaksWeb.PrivateAPI.ImportJSON
  alias Plug.Conn.Utils

  plug :require_api_scope, "packages:submit"

  @token_messages %{
    missing:
      "Dry-run first: POST this body with ?dry_run=true, show Jeff the report, then send its " <>
        "dry_run_token in the dry-run-token header.",
    expired: "The dry-run token has expired (tokens last 24 hours). Dry-run the body again.",
    invalid: "The dry-run token isn't valid. Send the dry_run_token a dry run returned.",
    body_mismatch:
      "The dry-run token is for a different body. Send exactly the bytes that were dry-run " <>
        "(curl --data-binary @file), or dry-run this body.",
    other_token:
      "The dry-run token was issued to another agent token. Dry-run with the token you apply with."
  }

  def create(conn, _params) do
    with :ok <- check_content_type(conn),
         {:ok, mode} <- mode(conn) do
      body = conn.body_params
      body_sha256 = Map.fetch!(conn.private, :body_sha256)

      conn
      |> run(mode, body, body_sha256)
      |> respond(conn, body_sha256)
    else
      {:error, status, message} -> error(conn, status, message)
    end
  end

  defp check_content_type(conn) do
    with [header] <- get_req_header(conn, "content-type"),
         {:ok, "application", "json", _params} <- Utils.content_type(header) do
      :ok
    else
      _ ->
        {:error, :unsupported_media_type,
         "The body must be JSON (content-type: application/json)."}
    end
  end

  # From the query string only: conn.params would also take a dry_run key
  # from the body.
  defp mode(conn) do
    case conn.query_params do
      %{"dry_run" => "true"} -> {:ok, :dry_run}
      %{"dry_run" => _} -> {:error, :bad_request, "dry_run must be true, or left out to apply."}
      _ -> {:ok, :apply}
    end
  end

  defp run(_conn, :dry_run, body, body_sha256), do: Import.dry_run(body, body_sha256)

  defp run(conn, :apply, body, body_sha256) do
    api_token = conn.assigns.current_api_token
    token = conn |> get_req_header("dry-run-token") |> List.first()

    with :not_applied <- Import.previously_applied(body, body_sha256),
         {:ok, plan_digest} <- verify_token(token, api_token, body_sha256) do
      Import.apply(body, body_sha256, plan_digest)
    end
  end

  defp verify_token(token, api_token, body_sha256) do
    case ImportDryRunToken.verify(token, api_token, body_sha256) do
      {:ok, plan_digest} -> {:ok, plan_digest}
      {:error, reason} -> {:token_error, reason}
    end
  end

  defp respond({:ok, report, plan_digest}, conn, body_sha256) do
    token = ImportDryRunToken.sign(conn.assigns.current_api_token, body_sha256, plan_digest)

    expires_at =
      DateTime.utc_now(:second) |> DateTime.add(ImportDryRunToken.max_age(), :second)

    json(conn, ImportJSON.dry_run(report, body_sha256, token, expires_at))
  end

  defp respond({:ok, report}, conn, body_sha256) do
    json(conn, ImportJSON.applied(report, body_sha256))
  end

  defp respond({:already_applied, applied}, conn, _body_sha256) do
    json(conn, ImportJSON.already_applied(applied))
  end

  defp respond({:token_error, reason}, conn, _body_sha256) do
    error(conn, :precondition_required, Map.fetch!(@token_messages, reason))
  end

  defp respond({:error, :plan_changed}, conn, _body_sha256) do
    error(conn, :conflict, "The database changed since the dry run. Dry-run the body again.")
  end

  defp respond({:error, :import_id_conflict}, conn, _body_sha256) do
    error(
      conn,
      :conflict,
      "This import_id was already applied with a different body. Use a new import_id."
    )
  end

  defp respond({:error, errors}, conn, _body_sha256) when is_list(errors) do
    conn |> put_status(:unprocessable_entity) |> json(ImportJSON.errors(errors))
  end

  defp error(conn, status, message) do
    conn |> put_status(status) |> json(%{error: message})
  end
end
