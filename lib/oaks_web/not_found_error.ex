defmodule OaksWeb.NotFoundError do
  @moduledoc """
  Raised by a LiveView when the thing its address names doesn't exist: a
  species, a taxon, a source or an article.

  Its `plug_status` is 404, so Phoenix renders `OaksWeb.ErrorHTML`'s 404
  page with a real 404 status instead of the LiveView rendering a
  not-found state of its own with 200. On a live navigation the mount
  fails the same way, and LiveView falls back to a page request, which
  gets the same 404 page.

  `kind` picks the page's wording and the index it offers
  (`OaksWeb.DesignComponents.not_found/1`); `query`, when set, fills in
  its search field (a species name asked for, say).

      raise OaksWeb.NotFoundError, kind: :species, query: name
  """

  @kinds [:page, :species, :taxon, :source, :article]

  defexception kind: :page, query: nil, plug_status: 404

  @type kind :: :page | :species | :taxon | :source | :article
  @type t :: %__MODULE__{kind: kind(), query: String.t() | nil, plug_status: 404}

  @doc "The kinds of thing a not-found page can be about."
  @spec kinds() :: [kind()]
  def kinds, do: @kinds

  @impl true
  def exception(opts) do
    kind = Keyword.get(opts, :kind, :page)

    unless kind in @kinds do
      raise ArgumentError, "unknown not-found kind: #{inspect(kind)}"
    end

    %__MODULE__{kind: kind, query: Keyword.get(opts, :query)}
  end

  @impl true
  def message(%__MODULE__{kind: :page}), do: "no page at this address"
  def message(%__MODULE__{kind: kind}), do: "no #{kind} at this address"
end
