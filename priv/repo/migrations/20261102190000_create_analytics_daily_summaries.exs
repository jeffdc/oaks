defmodule Oaks.Repo.Migrations.CreateAnalyticsDailySummaries do
  @moduledoc """
  Daily summary tables for page views, filled by `Oaks.Analytics.Rollup`.

  Raw `page_views` rows are kept for a limited window; past days are read
  from these tables instead. A `daily_stats` row also marks its day as
  rolled up.
  """
  use Ecto.Migration

  def change do
    create table(:daily_stats, primary_key: false) do
      add :date, :date, primary_key: true
      add :page_views, :integer, null: false
      add :unique_visitors, :integer, null: false
      add :not_found, :integer, null: false
      add :other_errors, :integer, null: false
    end

    create table(:daily_page_stats, primary_key: false) do
      add :date, :date, null: false
      add :path, :text, null: false
      add :page_views, :integer, null: false
      add :unique_visitors, :integer, null: false
    end

    create unique_index(:daily_page_stats, [:date, :path])

    create table(:daily_referrer_stats, primary_key: false) do
      add :date, :date, null: false
      add :referrer_host, :text, null: false
      add :page_views, :integer, null: false
    end

    create unique_index(:daily_referrer_stats, [:date, :referrer_host])

    # 404s keep only each day's most frequent paths; other errors are kept in full.
    create table(:daily_error_stats, primary_key: false) do
      add :date, :date, null: false
      add :path, :text, null: false
      add :status, :integer, null: false
      add :count, :integer, null: false
    end

    create unique_index(:daily_error_stats, [:date, :path, :status])
  end
end
