defmodule Oaks.Articles.Article do
  @moduledoc """
  Ecto schema for the articles table.

  Represents a reference article (guide, book review, etc.).
  Timestamps are stored as TEXT in SQLite, not Ecto-managed.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

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

  @doc """
  Full changeset used for database persistence.
  Requires slug and timestamps (set by context functions).
  """
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
    |> validate_required([:slug, :title, :author, :created_at, :updated_at])
    |> unique_constraint(:slug)
  end

  @doc """
  Form changeset for user input validation.
  Only validates fields the user controls (title, author, content, tags, is_published).
  """
  def form_changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :author, :content, :tags, :is_published])
    |> validate_required([:title, :author])
    |> validate_length(:title, max: 200)
    |> validate_length(:author, max: 200)
  end
end
