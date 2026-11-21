defmodule Oaks.Import.Body do
  @moduledoc """
  Checks the shape of a decoded import body and turns it into records for
  `Oaks.Import.Runner`, without touching the database.

  The body is a JSON object: an optional `"import_id"` and one key per
  table (`Oaks.Import.Tables`), each a list of records. A record is an object
  of the table's fields plus, optionally:

    * `"$ref"`: a name other records in the body use to point at it;
    * `"id"`: the id of an existing row to update;
    * `"$find"`: `{field: value, ...}` matching exactly one existing row to
      update.

  A foreign key (`Oaks.Import.Tables` `refs`) takes an integer id,
  `{"$ref": name}` or `{"$find": {...}}`. A `$ref` must name a record of the
  key's target table that comes earlier in processing order.

  Anything else is an error: unknown tables, fields and `$` keys, and refs
  that point forward, at another table, or at nothing. Every error found is
  returned, not just the first.
  """

  alias Oaks.Import.Tables

  @max_import_id_length 200

  @type fk ::
          {:id, pos_integer()} | {:ref, String.t()} | {:find, find()} | :null
  @type find :: %{table: Tables.t(), conditions: [{atom(), {:value, term()} | fk()}]}
  @type record :: %{
          table: Tables.t(),
          index: non_neg_integer(),
          ref: String.t() | nil,
          target: :new | {:id, pos_integer()} | {:find, find()},
          attrs: %{String.t() => term()},
          fks: %{atom() => fk()}
        }
  @type t :: %{import_id: String.t() | nil, tables: [String.t()], records: [record()]}
  @type error :: %{
          table: String.t() | nil,
          index: non_neg_integer() | nil,
          ref: String.t() | nil,
          field: String.t() | nil,
          message: String.t()
        }

  @doc """
  Checks `body` (a decoded JSON object) and returns its records in
  processing order, or every shape error found.
  """
  @spec parse(map()) :: {:ok, t()} | {:error, [error()]}
  def parse(%{"_json" => _}) do
    {:error, [body_error("the body must be a JSON object with one key per table")]}
  end

  def parse(body) when is_map(body) do
    {import_id, id_errors} = parse_import_id(body)
    key_errors = body |> Map.keys() |> Enum.sort() |> Enum.flat_map(&check_key/1)
    tables = Enum.filter(Tables.all(), &Map.has_key?(body, &1.name))

    empty_errors =
      if tables == [] and key_errors == [],
        do: [body_error("the body names no tables; give at least one of: #{table_list()}")],
        else: []

    {records, record_errors} = parse_tables(tables, body)
    ref_errors = check_refs(records)

    case id_errors ++ key_errors ++ empty_errors ++ record_errors ++ ref_errors do
      [] -> {:ok, %{import_id: import_id, tables: Enum.map(tables, & &1.name), records: records}}
      errors -> {:error, errors}
    end
  end

  @doc "The body's `import_id`, if it is a string, without checking anything else."
  @spec import_id(map()) :: String.t() | nil
  def import_id(%{"import_id" => id}) when is_binary(id), do: id
  def import_id(_body), do: nil

  ## Top level

  defp parse_import_id(body) do
    case Map.fetch(body, "import_id") do
      :error ->
        {nil, []}

      {:ok, id} when is_binary(id) and id != "" and byte_size(id) <= @max_import_id_length ->
        {id, []}

      {:ok, _} ->
        message = "must be a non-empty string of at most #{@max_import_id_length} bytes"
        {nil, [%{body_error(message) | field: "import_id"}]}
    end
  end

  defp check_key("import_id"), do: []

  defp check_key("dry_run") do
    [
      body_error(
        "dry_run doesn't go in the body: dry-run with POST /api/private/v1/import?dry_run=true"
      )
    ]
  end

  defp check_key(key) do
    if key in Tables.names(),
      do: [],
      else: [body_error("#{inspect(key)} is not a table the import accepts (#{table_list()})")]
  end

  defp table_list, do: Enum.join(Tables.names(), ", ")

  defp parse_tables(tables, body) do
    {records, errors} =
      Enum.reduce(tables, {[], []}, fn table, {records, errors} ->
        case Map.fetch!(body, table.name) do
          list when is_list(list) ->
            {table_records, table_errors} =
              list |> Enum.with_index() |> Enum.map(&parse_record(table, &1)) |> split()

            {Enum.reverse(table_records, records), Enum.reverse(table_errors, errors)}

          _ ->
            error = %{body_error("must be a list of records") | table: table.name}
            {records, [error | errors]}
        end
      end)

    {Enum.reverse(records), errors |> Enum.reverse() |> List.flatten()}
  end

  defp split(results) do
    Enum.reduce(results, {[], []}, fn
      {:ok, record}, {records, errors} -> {[record | records], errors}
      {:error, record_errors}, {records, errors} -> {records, [record_errors | errors]}
    end)
    |> then(fn {records, errors} -> {Enum.reverse(records), Enum.reverse(errors)} end)
  end

  ## Records

  defp parse_record(table, {raw, index}) when is_map(raw) do
    ref = parse_ref(raw)
    error = fn field, message -> record_error(table, index, ref, field, message) end

    acc = %{target: :new, attrs: %{}, fks: %{}, errors: []}

    acc =
      raw
      |> Enum.sort()
      |> Enum.reduce(acc, fn {key, value}, acc -> parse_entry(table, key, value, acc, error) end)

    acc =
      if Map.has_key?(raw, "id") and Map.has_key?(raw, "$find"),
        do: add(acc, error.("$find", "give either id or $find, not both")),
        else: acc

    case acc.errors do
      [] ->
        {:ok,
         %{
           table: table,
           index: index,
           ref: ref,
           target: acc.target,
           attrs: acc.attrs,
           fks: acc.fks
         }}

      errors ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp parse_record(table, {_raw, index}) do
    {:error, [record_error(table, index, nil, nil, "must be an object")]}
  end

  defp parse_ref(%{"$ref" => ref}) when is_binary(ref) and ref != "", do: ref
  defp parse_ref(_raw), do: nil

  defp parse_entry(_table, "$ref", value, acc, error) do
    if is_binary(value) and value != "",
      do: acc,
      else: add(acc, error.("$ref", "must be a non-empty string"))
  end

  defp parse_entry(table, "$find", value, acc, error) do
    case parse_find(table, value) do
      {:ok, find} -> %{acc | target: {:find, find}}
      {:error, message} -> add(acc, error.("$find", message))
    end
  end

  defp parse_entry(_table, "id", value, acc, error) do
    if is_integer(value) and value > 0,
      do: %{acc | target: {:id, value}},
      else: add(acc, error.("id", "must be the integer id of an existing row"))
  end

  defp parse_entry(_table, "$" <> _ = key, _value, acc, error) do
    add(acc, error.(key, "is not a key the import knows; use $ref or $find"))
  end

  defp parse_entry(table, key, value, acc, error) do
    case field(table, key) do
      nil ->
        add(acc, error.(key, "is not a field of #{table.name}"))

      field ->
        if Map.has_key?(table.refs, field),
          do: put_fk(table, field, key, value, acc, error),
          else: %{acc | attrs: Map.put(acc.attrs, key, value)}
    end
  end

  defp put_fk(table, field, key, value, acc, error) do
    case parse_fk(table, field, value) do
      {:ok, fk} -> %{acc | fks: Map.put(acc.fks, field, fk)}
      {:error, message} -> add(acc, error.(key, message))
    end
  end

  defp add(acc, error), do: %{acc | errors: [error | acc.errors]}

  defp field(table, key) do
    Enum.find(Tables.fields(table), &(Atom.to_string(&1) == key))
  end

  ## Foreign keys and $find

  defp parse_fk(_table, _field, nil), do: {:ok, :null}
  defp parse_fk(_table, _field, id) when is_integer(id) and id > 0, do: {:ok, {:id, id}}

  defp parse_fk(_table, _field, %{"$ref" => ref} = value)
       when is_binary(ref) and ref != "" and map_size(value) == 1,
       do: {:ok, {:ref, ref}}

  defp parse_fk(table, field, %{"$find" => conditions} = value) when map_size(value) == 1 do
    target = target_table(table, field)

    case parse_find(target, conditions) do
      {:ok, find} -> {:ok, {:find, find}}
      {:error, message} -> {:error, "$find: " <> message}
    end
  end

  defp parse_fk(_table, _field, _value) do
    {:error, ~s(must be an integer id, {"$ref": name} or {"$find": {field: value}})}
  end

  defp target_table(table, field) do
    name = Map.fetch!(table.refs, field)
    Enum.find(Tables.all(), &(&1.name == name))
  end

  defp parse_find(table, conditions) when is_map(conditions) and map_size(conditions) > 0 do
    conditions
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, acc} ->
      case parse_condition(table, key, value) do
        {:ok, condition} -> {:cont, {:ok, [condition | acc]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, %{table: table, conditions: Enum.reverse(parsed)}}
      error -> error
    end
  end

  defp parse_find(table, _conditions) do
    {:error, "must be an object of #{table.name} fields and the values to match"}
  end

  defp parse_condition(table, key, value) do
    field = if key == "id", do: :id, else: field(table, key)

    cond do
      field == nil -> {:error, "#{key} is not a field of #{table.name}"}
      Map.has_key?(table.refs, field) -> parse_fk_condition(table, field, key, value)
      is_map(value) or is_list(value) -> {:error, "#{key} must be a single value"}
      true -> parse_value_condition(table, field, key, value)
    end
  end

  defp parse_fk_condition(table, field, key, value) do
    case parse_fk(table, field, value) do
      {:ok, fk} -> {:ok, {field, fk}}
      {:error, message} -> {:error, "#{key} " <> message}
    end
  end

  defp parse_value_condition(table, field, key, value) do
    case Ecto.Type.cast(table.schema.__schema__(:type, field), value) do
      {:ok, cast} -> {:ok, {field, {:value, cast}}}
      _ -> {:error, "#{key} is not a valid #{field} value"}
    end
  end

  ## Refs

  # Walks the records in processing order, so a ref is known only once the
  # record that defines it has gone by.
  defp check_refs(records) do
    all_refs =
      for %{ref: ref} = record <- records, ref != nil, into: %{}, do: {ref, record.table.name}

    {_seen, errors} =
      Enum.reduce(records, {%{}, []}, fn record, {seen, errors} ->
        error = fn field, message ->
          record_error(record.table, record.index, record.ref, field, message)
        end

        fk_errors =
          record
          |> fk_uses()
          |> Enum.flat_map(fn {field, target, name} ->
            check_ref(name, target, seen, all_refs)
            |> List.wrap()
            |> Enum.map(&error.(field, &1))
          end)

        case record.ref do
          nil ->
            {seen, errors ++ fk_errors}

          ref when is_map_key(seen, ref) ->
            {table, index} = seen[ref]
            dup = error.("$ref", "#{ref} is already the $ref of #{table} record #{index}")
            {seen, errors ++ fk_errors ++ [dup]}

          ref ->
            {Map.put(seen, ref, {record.table.name, record.index}), errors ++ fk_errors}
        end
      end)

    errors
  end

  defp check_ref(name, target, seen, all_refs) do
    case seen do
      %{^name => {^target, _}} ->
        nil

      %{^name => {other, index}} ->
        "refers to #{name}, which is #{other} record #{index}, not a #{target} record"

      _ when is_map_key(all_refs, name) ->
        "refers to #{name}, which comes later in the body; a $ref can only point at an " <>
          "earlier record (tables go #{table_list()}, then array order)"

      _ ->
        "refers to #{name}, which no record in the body defines"
    end
  end

  # Every {"$ref": name} a record uses, with the field it appears under and
  # the table it must name, including refs nested in $find.
  defp fk_uses(record) do
    target_uses =
      case record.target do
        {:find, find} -> find_uses(find, "$find")
        _ -> []
      end

    fk_uses =
      Enum.flat_map(record.fks, fn {field, fk} ->
        fk_use(fk, Atom.to_string(field), Map.fetch!(record.table.refs, field))
      end)

    target_uses ++ fk_uses
  end

  defp fk_use({:ref, name}, field, target), do: [{field, target, name}]
  defp fk_use({:find, find}, field, _target), do: find_uses(find, field)
  defp fk_use(_fk, _field, _target), do: []

  defp find_uses(find, field) do
    Enum.flat_map(find.conditions, fn
      {_key, {:value, _}} -> []
      {key, fk} -> fk_use(fk, field, Map.fetch!(find.table.refs, key))
    end)
  end

  ## Errors

  defp body_error(message), do: %{table: nil, index: nil, ref: nil, field: nil, message: message}

  defp record_error(table, index, ref, field, message) do
    %{table: table.name, index: index, ref: ref, field: field, message: message}
  end
end
