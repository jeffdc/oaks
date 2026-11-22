defmodule OaksWeb.PrivateAPI.ImportControllerTest do
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures

  alias Oaks.Repo
  alias Oaks.Species.Species
  alias OaksWeb.ImportDryRunToken

  @body ~s({\n  "import_id": "web-test",\n  "species": [{"$ref": "web", "scientific_name": "webimportensis", "author": "Tester"}]\n}\n)

  setup %{conn: conn} do
    user = user_fixture()
    {raw, token} = api_token_fixture(user, %{"scopes" => ["packages:submit"]})

    # A fresh IP per test, so failure counts don't carry over.
    ip = "198.51.100.#{System.unique_integer([:positive])}"
    conn = put_req_header(conn, "fly-client-ip", ip)
    %{conn: conn, user: user, raw: raw, token: token}
  end

  defp post_import(conn, raw, body, opts \\ []) do
    path =
      if opts[:dry_run],
        do: ~p"/api/private/v1/import?dry_run=true",
        else: ~p"/api/private/v1/import"

    conn =
      conn
      |> put_req_header("content-type", Keyword.get(opts, :content_type, "application/json"))
      |> then(&if raw, do: put_req_header(&1, "authorization", "Bearer " <> raw), else: &1)
      |> then(&if t = opts[:token], do: put_req_header(&1, "dry-run-token", t), else: &1)

    post(conn, path, body)
  end

  defp dry_run!(conn, raw, body) do
    conn |> post_import(raw, body, dry_run: true) |> json_response(200)
  end

  defp sha256_hex(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

  describe "access" do
    test "needs an agent token", %{conn: conn} do
      assert conn |> post_import(nil, @body, dry_run: true) |> json_response(401)
    end

    test "needs the packages:submit scope", %{conn: conn, user: user} do
      {read_only, _} = api_token_fixture(user, %{"scopes" => ["materials:read"]})

      assert conn |> post_import(read_only, @body, dry_run: true) |> json_response(403) == %{
               "error" => "This token doesn't grant packages:submit."
             }
    end

    test "needs a JSON body", %{conn: conn, raw: raw} do
      conn = post_import(conn, raw, @body, dry_run: true, content_type: "text/plain")
      assert json_response(conn, 415)["error"] =~ "application/json"
    end

    test "refuses bad JSON", %{conn: conn, raw: raw} do
      conn = post_import(conn, raw, ~s({"species": [), dry_run: true)
      assert json_response(conn, 400)["error"] =~ "isn't valid JSON"
    end

    test "dry_run must be true when given", %{conn: conn, raw: raw} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer " <> raw)
        |> post("/api/private/v1/import?dry_run=false", @body)

      assert json_response(conn, 400)["error"] =~ "dry_run must be true"
    end
  end

  describe "dry run" do
    test "reports the plan, returns a token and writes nothing", %{conn: conn, raw: raw} do
      body = dry_run!(conn, raw, @body)

      assert body["status"] == "dry_run"
      assert body["body_sha256"] == sha256_hex(@body)
      assert is_binary(body["dry_run_token"])
      assert {:ok, expires_at, 0} = DateTime.from_iso8601(body["token_expires_at"])
      assert DateTime.diff(expires_at, DateTime.utc_now(), :hour) in 23..24
      assert body["summary"] == %{"species" => %{"create" => 1, "update" => 0, "unchanged" => 0}}

      assert body["records"] == [
               %{
                 "table" => "species",
                 "index" => 0,
                 "ref" => "web",
                 "action" => "create",
                 "changes" => %{"scientific_name" => "webimportensis", "author" => "Tester"}
               }
             ]

      refute Repo.get_by(Species, scientific_name: "webimportensis")
    end

    test "returns every error, one per message", %{conn: conn, raw: raw} do
      body = ~s({"dry_run": true, "species": [{"scientific_name": "webshape", "colour": "red"}]})
      response = conn |> post_import(raw, body, dry_run: true) |> json_response(422)

      assert [body_error, field_error] = response["errors"]

      assert %{"table" => nil, "index" => nil, "field" => nil, "message" => message} =
               body_error

      assert message =~ "?dry_run=true"

      assert field_error == %{
               "table" => "species",
               "index" => 0,
               "ref" => nil,
               "field" => "colour",
               "message" => "is not a field of species"
             }
    end
  end

  describe "apply" do
    test "applies with the dry run's token and records the import", %{conn: conn, raw: raw} do
      token = dry_run!(conn, raw, @body)["dry_run_token"]
      body = conn |> post_import(raw, @body, token: token) |> json_response(200)

      species = Repo.get_by!(Species, scientific_name: "webimportensis")
      assert body["status"] == "applied"
      assert body["body_sha256"] == sha256_hex(@body)
      assert [%{"action" => "create", "id" => id}] = body["records"]
      assert id == species.id

      for opts <- [[dry_run: true], [token: token]] do
        again = conn |> post_import(raw, @body, opts) |> json_response(200)
        assert again["status"] == "already_applied"
        assert again["import_id"] == "web-test"
        assert again["applied_at"]
      end
    end

    test "is refused without a dry-run token", %{conn: conn, raw: raw} do
      response = conn |> post_import(raw, @body) |> json_response(428)
      assert response["error"] =~ "Dry-run first"
      refute Repo.get_by(Species, scientific_name: "webimportensis")
    end

    test "is refused with a token for other bytes, even only whitespace", %{conn: conn, raw: raw} do
      token = dry_run!(conn, raw, @body)["dry_run_token"]
      reformatted = String.replace(@body, "\n", "")

      response = conn |> post_import(raw, reformatted, token: token) |> json_response(428)
      assert response["error"] =~ "different body"
      refute Repo.get_by(Species, scientific_name: "webimportensis")
    end

    test "is refused with a token from another agent token", %{conn: conn, user: user, raw: raw} do
      {other, _} = api_token_fixture(user, %{"scopes" => ["packages:submit"]})
      token = dry_run!(conn, raw, @body)["dry_run_token"]

      response = conn |> post_import(other, @body, token: token) |> json_response(428)
      assert response["error"] =~ "another agent token"
    end

    test "is refused with an expired or forged token", %{conn: conn, raw: raw, token: api_token} do
      signed_at = System.system_time(:second) - ImportDryRunToken.max_age() - 60

      expired =
        ImportDryRunToken.sign(api_token, :crypto.hash(:sha256, @body), <<0::256>>,
          signed_at: signed_at
        )

      response = conn |> post_import(raw, @body, token: expired) |> json_response(428)
      assert response["error"] =~ "expired"

      response = conn |> post_import(raw, @body, token: "not-a-token") |> json_response(428)
      assert response["error"] =~ "isn't valid"
    end

    test "is refused when the database changed since the dry run", %{conn: conn, raw: raw} do
      {:ok, species} = Oaks.Species.create_species(%{scientific_name: "webchanged", author: "A"})
      body = ~s({"species": [{"id": #{species.id}, "author": "B"}]})

      token = dry_run!(conn, raw, body)["dry_run_token"]
      {:ok, _} = Oaks.Species.update_species(species, %{author: "C"})

      response = conn |> post_import(raw, body, token: token) |> json_response(409)
      assert response["error"] =~ "changed since the dry run"
      assert Repo.get!(Species, species.id).author == "C"
    end

    test "an import_id applied with another body is a conflict", %{conn: conn, raw: raw} do
      token = dry_run!(conn, raw, @body)["dry_run_token"]
      assert conn |> post_import(raw, @body, token: token) |> json_response(200)

      other = String.replace(@body, "webimportensis", "webotherensis")
      response = conn |> post_import(raw, other, dry_run: true) |> json_response(409)
      assert response["error"] =~ "import_id was already applied"
    end
  end
end
