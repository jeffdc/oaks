defmodule OaksWeb.RedirectController do
  @moduledoc """
  Permanent redirects from old paths to their new homes, keeping the query
  string so bookmarked searches and filters still work.

  * `/list` → `/species` (the species index moved there in item 3248).
  """

  use OaksWeb, :controller

  @doc "Redirects `/list` to `/species`, query string included."
  def species_list(conn, _params) do
    to =
      case conn.query_string do
        "" -> ~p"/species"
        query -> ~p"/species" <> "?" <> query
      end

    conn
    |> put_status(:moved_permanently)
    |> redirect(to: to)
  end
end
