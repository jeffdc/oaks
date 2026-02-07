defmodule OakCompendium.Articles.Article do
  @moduledoc """
  Ecto schema for the articles table.

  Represents a reference article (guide, book review, etc.).
  Timestamps are stored as TEXT in SQLite, not Ecto-managed.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:slug, :title, :author, :created_at, :updated_at]

  schema "articles" do
    field :slug, :string
    field :title, :string
    field :author, :string
    field :content, :string
    field :tags, :string
    field :is_published, :boolean, default: false
    field :created_at, :string
    field :updated_at, :string
    field :published_at, :string
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [
      :slug,
      :title,
      :author,
      :content,
      :tags,
      :is_published,
      :created_at,
      :updated_at,
      :published_at
    ])
    |> validate_required(@required_fields)
    |> unique_constraint(:slug)
  end
end
