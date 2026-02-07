defmodule OakCompendium.Markdown do
  @moduledoc """
  Shared markdown rendering using Earmark.
  """

  @spec render_html(String.t() | nil) :: String.t()
  def render_html(nil), do: ""
  def render_html(""), do: ""

  def render_html(content) when is_binary(content) do
    case Earmark.as_html(content) do
      {:ok, html, _warnings} -> html
      {:error, _html, _errors} -> content
    end
  end
end
