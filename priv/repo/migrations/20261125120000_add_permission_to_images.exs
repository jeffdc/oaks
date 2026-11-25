defmodule Oaks.Repo.Migrations.AddPermissionToImages do
  use Ecto.Migration

  # An All Rights Reserved photo is imported only with an editor's
  # confirmation that its creator gave permission: who confirmed it and when
  # (docs/species-photos-plan.md, Phase 5). Nil for openly licensed photos.
  def change do
    alter table(:images) do
      add :permission_confirmed_by, :string
      add :permission_confirmed_at, :utc_datetime
    end
  end
end
