defmodule Oaks.ChangesetHelpers do
  @moduledoc """
  Shared changeset normalization and validation for schemas.

  Cribbed from gallformers (`Gallformers.ChangesetHelpers`).
  """
  import Ecto.Changeset

  @url_message "must be a valid URL starting with http:// or https://"

  @doc """
  Trims leading and trailing whitespace from every changed string field.

  Looks up the schema's persisted `:string` fields, so virtual fields (such as
  a password), arrays, binaries and other types are left alone. Inner
  whitespace is kept. A value that trims to what is already stored stops being
  a change at all, so a whitespace-only edit doesn't count as an edit.

  Place it right after `cast/3`, before any `validate_*` calls.
  """
  @spec trim_strings(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def trim_strings(%Ecto.Changeset{data: %schema{}} = changeset) do
    :fields
    |> schema.__schema__()
    |> Enum.filter(&(schema.__schema__(:type, &1) == :string))
    |> Enum.reduce(changeset, &maybe_trim_field/2)
  end

  defp maybe_trim_field(field, changeset) do
    case get_change(changeset, field) do
      value when is_binary(value) ->
        trimmed = String.trim(value)
        if trimmed == value, do: changeset, else: put_change(changeset, field, trimmed)

      _ ->
        changeset
    end
  end

  @doc """
  Normalizes and validates a URL field.

  The change is trimmed, and a value starting with `www.` gets `https://` put
  in front of it. A non-empty change must then have an `http` or `https`
  scheme and a host. Only a change is checked, so a URL already stored doesn't
  block edits to other fields.
  """
  @spec validate_url(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_url(changeset, field) do
    changeset
    |> normalize_url(field)
    |> validate_change(field, &check_url_format/2)
  end

  defp normalize_url(changeset, field) do
    case get_change(changeset, field) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        normalized =
          if String.starts_with?(trimmed, "www."), do: "https://" <> trimmed, else: trimmed

        put_change(changeset, field, normalized)

      _ ->
        changeset
    end
  end

  defp check_url_format(_field, ""), do: []

  defp check_url_format(field, value) do
    case URI.parse(value) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        []

      _ ->
        [{field, @url_message}]
    end
  end

  @doc """
  Turns an empty-string change into `nil` for each of `fields`.

  `cast/3` already does this for the fields it casts (Ecto's `empty_values`),
  so this is for changes made with `put_change/3` or `change/2`.
  """
  @spec empty_strings_to_nil(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  def empty_strings_to_nil(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, cs ->
      case get_change(cs, field) do
        "" -> put_change(cs, field, nil)
        _ -> cs
      end
    end)
  end
end
