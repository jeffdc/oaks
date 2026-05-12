defmodule Oaks.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views) do
      add :path, :text, null: false
      add :status, :integer, null: false
      add :referrer_host, :string
      add :browser, :string
      add :device_type, :string
      add :visitor_hash, :string, null: false, size: 64

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:page_views, [:inserted_at])
    create index(:page_views, [:path])
    create index(:page_views, [:status])
    create index(:page_views, [:visitor_hash, :inserted_at])
  end
end
