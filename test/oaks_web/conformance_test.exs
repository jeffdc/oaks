defmodule OaksWeb.ConformanceTest do
  use ExUnit.Case, async: true

  alias OaksWeb.Conformance

  defp lines(text, rule), do: text |> Conformance.scan([rule]) |> Enum.map(& &1.line)

  describe "width" do
    test "counts page-scale widths and max-w with mx-auto, variants included" do
      text = """
      <div class="max-w-4xl">
      <div class="md:max-w-screen-lg">
      <div class="max-w-prose px-4">
      <div class="max-w-md mx-auto">
      <div class="max-w-[68ch] mx-auto">
      """

      assert lines(text, :width) == [1, 2, 3, 4, 5]
    end

    test "leaves element widths, text measures and comments alone" do
      text = """
      <div class="max-w-md">
      <p class="max-w-[68ch]">
      <div class="page-max-w-4xl">
      # <div class="max-w-4xl">
      <%!-- <div class="max-w-4xl"> --%>
      """

      assert lines(text, :width) == []
    end
  end

  describe "style" do
    test "counts style attributes, not style= inside an Elixir string" do
      text = """
      <div style="color: red">
      <div style={@style}>
      "Write <span style=\\"x\\">"
      <div data-style="x">
      """

      assert lines(text, :style) == [1, 2]
    end
  end

  describe "daisyui" do
    test "counts card and badge tokens in class values and class strings" do
      text = """
      <div class="card">
      <span class={["badge-muted", @x]}>
      class = "badge badge-muted"
      """

      assert lines(text, :daisyui) == [1, 2, 3]
    end

    test "leaves page classes and prose alone" do
      text = """
      <div class="taxon-card comparison-preferred-badge">
      <.stamp badge="x" />
      <p>Each card shows a badge.</p>
      """

      assert lines(text, :daisyui) == []
    end
  end

  describe "sci_name" do
    test "counts italics that name a taxon, even when the element spans lines" do
      text = """
      <i>{@species.scientific_name}</i>
      <em>
        Quercus alba
      </em>
      <span class="italic">{@taxon.name}</span>
      <i>{@note}</i>
      <span class="not-italic">{@species.scientific_name}</span>
      """

      assert Conformance.sci_name_lines(text) == [1, 2, 5]
    end

    test "counts name helpers, one per clause, and the abbreviated genus" do
      text = """
      defp sci_label(s), do: s
      def species_binomial(s), do: s
      defp epithet(s), do: s
      "Q. \#{@species.name}"
      defp label(s), do: s
      # defp sci_label(s), do: s
      """

      assert Conformance.sci_name_lines(text) == [1, 2, 3, 4]
    end

    test "leaves plain-text names alone" do
      assert Conformance.sci_name_lines(~S|<.sci_name name={"Quercus #{@x}"} />|) == []
      assert Conformance.sci_name_lines("<i>{@note}</i>\n<img src={@url} />") == []
    end
  end
end
