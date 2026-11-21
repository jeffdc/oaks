defmodule Oaks.Import do
  @moduledoc """
  Bulk changes through one endpoint (item f8f5, decision e661): a JSON body
  shaped like the data model, one key per table (`Oaks.Import.Tables`), whose
  records go through their schemas' changesets and apply in one transaction
  or not at all. `docs/import.md` describes the body for producers.

  Every import is dry-run first (decision 62ae). `dry_run/2` reports what
  would change, writes nothing, and returns a digest of that plan;
  `OaksWeb.ImportDryRunToken` signs the digest with the body's hash into the
  token an apply must carry. `apply/3` runs the body again and commits only
  if the plan is the same, so what Jeff read in the dry-run report is what
  applies.

  Every applied body is recorded (`Oaks.Import.AppliedImport`), so sending
  it again, or another body with the same `import_id`, changes nothing.

  Creates and updates only: no upserts, no deletes.
  """

  require Logger

  alias Oaks.Import.AppliedImport
  alias Oaks.Import.Body
  alias Oaks.Import.Runner

  @type error :: Body.error()
  @type record_report :: %{
          required(:table) => String.t(),
          required(:index) => non_neg_integer(),
          required(:ref) => String.t() | nil,
          required(:action) => String.t(),
          optional(:id) => integer(),
          required(:changes) => map()
        }
  @type report :: %{
          summary: %{String.t() => %{create: integer(), update: integer(), unchanged: integer()}},
          records: [record_report()]
        }

  @doc """
  Validates `body` (the decoded request body, whose raw bytes hash to
  `body_sha256`) and reports what applying it would do, writing nothing.

  Returns the report and the plan digest to sign into the dry-run token,
  the ledger entry if this import was already applied, or the errors.
  """
  @spec dry_run(map(), binary()) ::
          {:ok, report(), binary()}
          | {:already_applied, AppliedImport.t()}
          | {:error, [error()]}
          | {:error, :import_id_conflict}
  def dry_run(body, body_sha256) do
    with :not_applied <- previously_applied(body, body_sha256),
         {:ok, parsed} <- Body.parse(body),
         {:ok, results} <- Runner.run(parsed, body_sha256, :dry_run) do
      {:ok, report(parsed, results, :dry_run), Runner.plan_digest(results)}
    end
  end

  @doc """
  Applies `body` if it still does what its dry run reported:
  `expected_plan_digest` comes from the dry-run token. Records the import in
  the ledger in the same transaction.

  Returns `{:error, :plan_changed}`, writing nothing, if the database has
  changed since the dry run so that the result would differ.
  """
  @spec apply(map(), binary(), binary()) ::
          {:ok, report()}
          | {:already_applied, AppliedImport.t()}
          | {:error, [error()]}
          | {:error, :plan_changed}
          | {:error, :import_id_conflict}
  def apply(body, body_sha256, expected_plan_digest) do
    with :not_applied <- previously_applied(body, body_sha256),
         {:ok, parsed} <- Body.parse(body),
         {:ok, results} <- Runner.run(parsed, body_sha256, {:apply, expected_plan_digest}) do
      report = report(parsed, results, :apply)
      log_apply(parsed, body_sha256, report)
      {:ok, report}
    end
  end

  @doc """
  Looks an import up in the ledger: `{:already_applied, entry}` if this body
  was applied (or its `import_id` was, with this body),
  `{:error, :import_id_conflict}` if its `import_id` was applied with another
  body, `:not_applied` otherwise. `dry_run/2` and `apply/3` check this
  themselves; the endpoint also checks it before the dry-run token.
  """
  @spec previously_applied(map(), binary()) ::
          :not_applied | {:already_applied, AppliedImport.t()} | {:error, :import_id_conflict}
  def previously_applied(body, body_sha256) do
    case Runner.ledger(body_sha256, Body.import_id(body)) do
      :import_id_conflict -> {:error, :import_id_conflict}
      other -> other
    end
  end

  # Creates show their ids only once applied: a dry run's are rolled back,
  # and SQLite may hand the same ids to other rows.
  defp report(parsed, results, mode) do
    empty = %{create: 0, update: 0, unchanged: 0}
    summary = Map.new(parsed.tables, &{&1, empty})

    summary =
      Enum.reduce(results, summary, fn result, summary ->
        update_in(summary, [result.table, result.action], &(&1 + 1))
      end)

    records =
      Enum.map(results, fn result ->
        record = %{
          table: result.table,
          index: result.index,
          ref: result.ref,
          action: Atom.to_string(result.action),
          changes: result.changes
        }

        if result.action == :create and mode == :dry_run,
          do: record,
          else: Map.put(record, :id, result.id)
      end)

    %{summary: summary, records: records}
  end

  defp log_apply(parsed, body_sha256, report) do
    counts =
      Enum.map_join(parsed.tables, ", ", fn name ->
        c = Map.fetch!(report.summary, name)
        "#{name} #{c.create}/#{c.update}/#{c.unchanged}"
      end)

    hash = body_sha256 |> Base.encode16(case: :lower) |> binary_part(0, 12)

    Logger.info(
      "Import applied: import_id=#{inspect(parsed.import_id)} body=#{hash} " <>
        "(created/updated/unchanged) #{counts}"
    )
  end
end
