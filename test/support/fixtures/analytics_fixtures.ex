defmodule Oaks.AnalyticsFixtures do
  @moduledoc """
  Test fixtures for the `Oaks.Analytics` context.
  """

  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  @doc """
  Inserts a `PageView` with sensible defaults, overridable via `attrs`.

  Accepts `inserted_at` (a `DateTime` or `NaiveDateTime`) to backdate rows;
  the schema's `changeset/2` doesn't cast timestamps, so it's set on the
  struct directly.
  """
  @spec page_view_fixture(map() | keyword()) :: PageView.t()
  def page_view_fixture(attrs \\ %{}) do
    defaults = %{
      path: "/species/quercus-alba",
      status: 200,
      referrer_host: nil,
      visitor_hash: String.duplicate("a", 64),
      inserted_at: DateTime.utc_now()
    }

    attrs = Enum.into(attrs, defaults)
    {inserted_at, changeset_attrs} = Map.pop(attrs, :inserted_at)

    {:ok, pv} =
      %PageView{}
      |> PageView.changeset(changeset_attrs)
      |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
      |> Repo.insert()

    pv
  end
end
