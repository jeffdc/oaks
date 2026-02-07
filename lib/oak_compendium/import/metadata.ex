defmodule OakCompendium.Import.Metadata do
  @moduledoc """
  Ecto schema for the import_metadata table.

  Key-value store for tracking incremental import state.
  Uses `key` (text) as the primary key instead of an integer id.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:key, :string, autogenerate: false}

  schema "import_metadata" do
    field :value, :string
  end

  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
  end
end
