defmodule Oaks.Repo.Migrations.CreateImages do
  use Ecto.Migration

  # Species photos imported from iNaturalist (docs/species-photos-plan.md,
  # Phase 3), the attempts that store their files, and the cleanups that
  # remove files no longer wanted. See Oaks.Images.
  def change do
    create table(:images) do
      # Restrict, not cascade: deleting a species must remove its photos
      # through Oaks.Images, which records their files for cleanup.
      add :species_id, references(:species, on_delete: :restrict), null: false
      # The published original's path (Oaks.Storage.Images); nil until ready.
      add :path, :string
      add :sort_order, :integer, null: false
      add :caption, :text
      add :creator, :string, null: false
      add :license, :string, null: false
      add :licenselink, :string
      add :sourcelink, :string, null: false
      add :inat_observation_id, :integer, null: false
      add :inat_photo_id, :integer, null: false
      add :uploader, :string, null: false
      add :lastchangedby, :string, null: false

      add :status, :string,
        null: false,
        default: "pending",
        check: %{name: "images_status", expr: "status IN ('pending', 'ready', 'failed')"}

      add :last_error, :text
      # The attempt allowed to publish this photo (image_import_attempts).
      add :current_attempt_id, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:images, [:species_id, :inat_photo_id])
    create index(:images, [:species_id, :sort_order])

    create table(:image_import_attempts) do
      # Nilified, not deleted, with the image: a worker still holding the
      # attempt's lease must find it cancelled, and its cleanup waits on it.
      add :image_id, references(:images, on_delete: :nilify_all)
      add :original_path, :string, null: false
      add :photo_url, :string, null: false

      add :state, :string,
        null: false,
        default: "queued",
        check: %{
          name: "image_import_attempts_state",
          expr: "state IN ('queued', 'running', 'published', 'failed', 'cancelled')"
        }

      # When all five files were stored: a worker resuming the attempt then
      # only has to publish it.
      add :stored_at, :utc_datetime_usec

      # The claim a worker holds while it runs: no other worker may run the
      # attempt, and no cleanup may remove its files, until the lease ends.
      add :lease_token, :string
      add :lease_until, :utc_datetime_usec
      add :tries, :integer, null: false, default: 0
      add :last_error, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:image_import_attempts, [:original_path])
    create index(:image_import_attempts, [:image_id])
    create index(:image_import_attempts, [:state])

    # No foreign keys: a cleanup outlives the image, species and attempts it
    # removes files for.
    create table(:image_cleanups) do
      add :paths, :text, null: false
      add :attempt_ids, :text, null: false
      add :reason, :string, null: false
      add :image_id, :integer
      add :species_id, :integer

      add :state, :string,
        null: false,
        default: "deleting",
        check: %{
          name: "image_cleanups_state",
          expr: "state IN ('deleting', 'invalidating', 'done')"
        }

      add :invalidation_id, :string
      add :tries, :integer, null: false, default: 0
      add :last_error, :text
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:image_cleanups, [:state])
  end
end
