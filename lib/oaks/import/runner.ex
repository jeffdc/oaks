defmodule Oaks.Import.Runner do
  @moduledoc """
  Runs the records of a checked body (`Oaks.Import.Body`) in one
  transaction.

  Each record is resolved (its foreign keys and, for an update, its row),
  put through its table's changeset and written, in order. An error doesn't
  stop the run: a failed statement doesn't abort a SQLite transaction, so the
  run carries on to collect every record's errors, and rolls back at the end
  if there were any. A dry run always rolls back. An apply commits only if
  the plan matches the dry run's and records the body in the ledger
  (`Oaks.Import.AppliedImport`) in the same transaction.

  Ecto.Multi isn't used because it stops at the first error, and context
  functions aren't called because they open transactions of their own.
  """

  import Ecto.Query

  alias Oaks.Import.AppliedImport
  alias Oaks.Import.Body
  alias Oaks.Import.Tables
  alias Oaks.Repo

  @type action :: :create | :update | :unchanged
  @type result :: %{
          table: String.t(),
          index: non_neg_integer(),
          ref: String.t() | nil,
          action: action(),
          id: integer(),
          changes: map()
        }
  @type mode :: :dry_run | {:apply, binary()}
  @type ledger :: :not_applied | {:already_applied, AppliedImport.t()} | :import_id_conflict

  @doc """
  Runs `body` as a dry run or an apply. Returns the results, which a dry run
  has rolled back, or why nothing was written.
  """
  @spec run(Body.t(), binary(), mode()) ::
          {:ok, [result()]}
          | {:already_applied, AppliedImport.t()}
          | {:error, [Body.error()] | :plan_changed | :import_id_conflict}
  def run(body, body_sha256, mode) do
    Repo.transact(fn ->
      # Checked again inside the (immediate, so write-locked) transaction, in
      # case the same import was applied since the caller looked.
      case ledger(body_sha256, body.import_id) do
        :not_applied -> run_records(body, body_sha256, mode)
        other -> {:error, {:ledger, other}}
      end
    end)
    |> case do
      {:ok, results} -> {:ok, results}
      {:error, {:dry_run, results}} -> {:ok, results}
      {:error, {:ledger, :import_id_conflict}} -> {:error, :import_id_conflict}
      {:error, {:ledger, already_applied}} -> already_applied
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Looks `body_sha256` and `import_id` up in the ledger: an applied import
  with this body, or with this `import_id` and another body (a conflict).
  """
  @spec ledger(binary(), String.t() | nil) :: ledger()
  def ledger(body_sha256, import_id) do
    by_body = Repo.get_by(AppliedImport, body_sha256: body_sha256)
    by_id = import_id && Repo.get_by(AppliedImport, import_id: import_id)

    cond do
      by_body -> {:already_applied, by_body}
      by_id -> :import_id_conflict
      true -> :not_applied
    end
  end

  @doc """
  The digest of what a run did: each record's table, index, action, updated
  row id and changes, leaving out the ids of new rows (an apply can get
  different ones). An apply must produce the digest its dry run did.
  """
  @spec plan_digest([result()]) :: binary()
  def plan_digest(results) do
    plan =
      Enum.map(results, fn result ->
        id = if result.action == :create, do: nil, else: result.id
        {result.table, result.index, result.action, id, result.changes}
      end)

    :crypto.hash(:sha256, :erlang.term_to_binary(plan, [:deterministic]))
  end

  defp run_records(body, body_sha256, mode) do
    state = Enum.reduce(body.records, %{refs: %{}, errors: [], results: []}, &run_record/2)
    results = Enum.reverse(state.results)

    case {state.errors, mode} do
      {[_ | _] = errors, _mode} ->
        {:error, errors |> Enum.reverse() |> List.flatten()}

      {[], :dry_run} ->
        {:error, {:dry_run, results}}

      {[], {:apply, expected_digest}} ->
        if plan_digest(results) == expected_digest do
          Repo.insert!(%AppliedImport{body_sha256: body_sha256, import_id: body.import_id})
          {:ok, results}
        else
          {:error, :plan_changed}
        end
    end
  end

  ## One record

  defp run_record(record, state) do
    error = fn field, message ->
      %{
        table: record.table.name,
        index: record.index,
        ref: record.ref,
        field: field,
        message: message
      }
    end

    with {:ok, fk_ids, fk_shown} <- resolve_fks(record, state, error),
         {:ok, row, action} <- resolve_target(record, state, error) do
      record
      |> changeset(row, action, fk_ids)
      |> write(record, row, action, fk_shown, state, error)
    else
      {:error, errors} -> fail(state, record, errors)
    end
  end

  defp resolve_fks(record, state, error) do
    record.fks
    |> Enum.sort()
    |> Enum.reduce({%{}, %{}, []}, fn {field, fk}, {ids, shown, errors} ->
      target = Map.fetch!(record.table.refs, field)

      case resolve_fk(fk, target, state) do
        {:ok, id, show} ->
          {Map.put(ids, Atom.to_string(field), id), Map.put(shown, field, show), errors}

        {:error, message} ->
          {ids, shown, [error.(Atom.to_string(field), message) | errors]}
      end
    end)
    |> case do
      {ids, shown, []} -> {:ok, ids, shown}
      {_ids, _shown, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  # Returns {:ok, id, how the report shows it}: a $ref shows as itself, since
  # a new row's id differs between the dry run and the apply.
  defp resolve_fk(:null, _target, _state), do: {:ok, nil, nil}

  defp resolve_fk({:id, id}, target, _state) do
    schema = table(target).schema

    if Repo.exists?(from(r in schema, where: r.id == ^id)),
      do: {:ok, id, id},
      else: {:error, "no #{target} record has id #{id}"}
  end

  defp resolve_fk({:ref, name}, _target, state) do
    case Map.fetch!(state.refs, name) do
      {:ok, id} -> {:ok, id, %{"$ref" => name}}
      :failed -> {:error, "refers to #{name}, which has errors"}
    end
  end

  defp resolve_fk({:find, find}, _target, state) do
    case find_one(find, state) do
      {:ok, row} -> {:ok, row.id, row.id}
      {:error, message} -> {:error, "$find " <> message}
    end
  end

  defp resolve_target(%{target: :new} = record, _state, _error),
    do: {:ok, struct(record.table.schema), :create}

  defp resolve_target(%{target: {:id, id}} = record, _state, error) do
    case Repo.get(record.table.schema, id) do
      nil -> {:error, [error.("id", "no #{record.table.name} record has id #{id}")]}
      row -> {:ok, row, :update}
    end
  end

  defp resolve_target(%{target: {:find, find}}, state, error) do
    case find_one(find, state) do
      {:ok, row} -> {:ok, row, :update}
      {:error, message} -> {:error, [error.("$find", message)]}
    end
  end

  defp find_one(find, state) do
    query =
      Enum.reduce_while(find.conditions, {:ok, from(r in find.table.schema)}, fn
        {field, {:value, nil}}, {:ok, query} ->
          {:cont, {:ok, where(query, [r], is_nil(field(r, ^field)))}}

        {field, {:value, value}}, {:ok, query} ->
          {:cont, {:ok, where(query, [r], field(r, ^field) == ^value)}}

        {field, fk}, {:ok, query} ->
          target = Map.fetch!(find.table.refs, field)

          case resolve_fk(fk, target, state) do
            {:ok, nil, _} -> {:cont, {:ok, where(query, [r], is_nil(field(r, ^field)))}}
            {:ok, id, _} -> {:cont, {:ok, where(query, [r], field(r, ^field) == ^id)}}
            {:error, message} -> {:halt, {:error, "#{field} " <> message}}
          end
      end)

    with {:ok, query} <- query do
      case Repo.all(limit(query, 2)) do
        [row] -> {:ok, row}
        [] -> {:error, "matches no #{find.table.name} record"}
        [_, _] -> {:error, "matches more than one #{find.table.name} record; it must match one"}
      end
    end
  end

  defp changeset(record, row, action, fk_ids) do
    table = record.table
    changeset = table.changeset.(row, Map.merge(record.attrs, fk_ids))

    changeset =
      if action == :update,
        do: Enum.reduce(table.immutable_on_update, changeset, &refuse_change/2),
        else: changeset

    if table.prepare, do: table.prepare.(changeset, action), else: changeset
  end

  defp refuse_change(field, changeset) do
    if Ecto.Changeset.changed?(changeset, field),
      do:
        Ecto.Changeset.add_error(
          changeset,
          field,
          "can't be changed by an import; rename it in the app"
        ),
      else: changeset
  end

  defp write(
         %Ecto.Changeset{valid?: false} = changeset,
         record,
         _row,
         _action,
         _shown,
         state,
         error
       ) do
    fail(state, record, changeset_errors(changeset, error))
  end

  defp write(%Ecto.Changeset{changes: changes}, record, row, :update, _shown, state, _error)
       when changes == %{} do
    succeed(state, record, row.id, :unchanged, %{})
  end

  defp write(changeset, record, row, action, shown, state, error) do
    case insert_or_update(changeset, action) do
      {:ok, written} ->
        succeed(state, record, written.id, action, report_changes(changeset, row, action, shown))

      {:error, changeset} ->
        fail(state, record, changeset_errors(changeset, error))
    end
  end

  # FKs are checked before writing, but a constraint the changeset doesn't
  # declare would still raise; report it on the record instead.
  defp insert_or_update(changeset, action) do
    if action == :create, do: Repo.insert(changeset), else: Repo.update(changeset)
  rescue
    e in Ecto.ConstraintError ->
      {:error,
       Ecto.Changeset.add_error(changeset, :base, "violates the #{e.constraint} constraint")}
  end

  defp report_changes(changeset, row, action, shown) do
    Map.new(changeset.changes, fn {field, value} ->
      to = Map.get(shown, field, value)
      change = if action == :create, do: to, else: %{"from" => Map.get(row, field), "to" => to}
      {Atom.to_string(field), change}
    end)
  end

  defp changeset_errors(changeset, error) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.sort()
    |> Enum.flat_map(fn {field, messages} ->
      field = if field == :base, do: nil, else: Atom.to_string(field)
      Enum.map(messages, &error.(field, &1))
    end)
  end

  defp succeed(state, record, id, action, changes) do
    result = %{
      table: record.table.name,
      index: record.index,
      ref: record.ref,
      action: action,
      id: id,
      changes: changes
    }

    %{state | refs: put_ref(state.refs, record.ref, {:ok, id}), results: [result | state.results]}
  end

  defp fail(state, record, errors) do
    %{state | refs: put_ref(state.refs, record.ref, :failed), errors: [errors | state.errors]}
  end

  defp put_ref(refs, nil, _value), do: refs
  defp put_ref(refs, ref, value), do: Map.put(refs, ref, value)

  defp table(name), do: Enum.find(Tables.all(), &(&1.name == name))
end
