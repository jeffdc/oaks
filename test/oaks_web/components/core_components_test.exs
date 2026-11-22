defmodule OaksWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias OaksWeb.CoreComponents

  defp text_slot(text), do: [%{inner_block: fn _, _ -> text end}]

  describe "button/1" do
    test "defaults to the ghost outline" do
      html = render_component(&CoreComponents.button/1, inner_block: text_slot("Set aside"))
      assert html =~ ~s(<button class="oc-btn">)
    end

    test "primary is the ochre fill; compact is the Compare size" do
      html =
        render_component(&CoreComponents.button/1,
          variant: "primary",
          size: "compact",
          inner_block: text_slot("Insert")
        )

      assert html =~ "oc-btn oc-btn-primary oc-btn-compact"
    end

    test "renders a link when given a destination" do
      html =
        render_component(&CoreComponents.button/1,
          navigate: "/sources",
          inner_block: text_slot("Go")
        )

      assert html =~ ~r{<a [^>]*href="/sources"}
      assert html =~ "oc-btn"
    end
  end

  test "header/1 puts the title, subtitle and actions on the title row" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.header>
        Sources
        <:subtitle>Every work the Compendium cites.</:subtitle>
        <:actions><button>Add</button></:actions>
      </CoreComponents.header>
      """)

    assert html =~ ~r{<header class="oc-title\s*">}
    assert html =~ ~r{<h1>\s*Sources\s*</h1>}
    assert html =~ ~s(<p class="oc-title-sub">Every work the Compendium cites.</p>)
    assert html =~ ~s(<div class="oc-title-actions">)
  end

  describe "table/1" do
    test "renders a ruled table with row headers, a voice column and stacking labels" do
      assigns = %{rows: [%{trait: "Buds", jeff: "buds looks glabrous"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="marks" rows={@rows} stack>
          <:col :let={row} label="Trait" row_header>{row.trait}</:col>
          <:col :let={row} label="Jeff Clark" voice>{row.jeff}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~r{<div class="oc-table-wrap oc-table-stack\s*">}
      assert html =~ ~s(<table class="oc-table">)
      assert html =~ ~s(<th scope="col">Trait</th>)
      assert html =~ ~r{<th scope="row"[^>]*>\s*Buds\s*</th>}
      assert html =~ ~r{<td data-label="Jeff Clark" class="oc-voice\s*">\s*buds looks glabrous}
    end

    test "without stack the table only scrolls" do
      assigns = %{rows: [%{n: 1}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="plain" rows={@rows}>
          <:col :let={row} label="n">{row.n}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~r{<div class="oc-table-wrap\s*">}
    end
  end

  test "list/1 renders terms beside values" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.list>
        <:item title="Authority">Buckley</:item>
      </CoreComponents.list>
      """)

    assert html =~ ~s(<dl class="oc-list">)
    assert html =~ "<dt>Authority</dt>"
    assert html =~ ~r{<dd>\s*Buckley\s*</dd>}
  end

  test "modal/1 renders a titled dialog with a Close button" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.modal id="confirm">
        <:title>Discard your changes?</:title>
        The edits will be lost.
      </CoreComponents.modal>
      """)

    assert html =~ ~s(role="dialog")
    assert html =~ ~s(aria-labelledby="confirm-title")
    assert html =~ "oc-modal-panel"
    assert html =~ ~r{Close <kbd>Esc</kbd>}
  end

  test "back/1 renders a back link" do
    html =
      render_component(&CoreComponents.back/1,
        navigate: "/list",
        inner_block: text_slot("All species")
      )

    assert html =~ ~r{<a [^>]*href="/list"[^>]*class="oc-back"}
  end

  describe "flash/1" do
    test "an info notice is the paper notice" do
      html = render_component(&CoreComponents.flash/1, kind: :info, flash: %{"info" => "Saved."})
      assert html =~ ~r{class="oc-flash\s*"}
      assert html =~ "Saved."
    end

    test "an error reverses to the ink plate, with its title" do
      html =
        render_component(&CoreComponents.flash/1,
          kind: :error,
          title: "Something went wrong!",
          flash: %{"error" => "Try again."}
        )

      assert html =~ ~r{class="oc-flash oc-flash-error\s*"}
      assert html =~ ~s(<p class="oc-flash-title">Something went wrong!</p>)
    end

    test "renders nothing without a message" do
      assert render_component(&CoreComponents.flash/1, kind: :info, flash: %{}) == ""
    end
  end

  describe "input/1" do
    test "a text field is labelled and marked invalid when it has errors" do
      html =
        render_component(&CoreComponents.input/1,
          name: "authority",
          label: "Authority",
          value: "",
          errors: ["can't be blank"]
        )

      assert html =~ ~s(<span class="oc-label">Authority</span>)
      assert html =~ ~r{class="oc-input\s*"}
      assert html =~ ~s(aria-invalid="true")
      assert html =~ ~s(<p class="oc-error">)
      assert html =~ "can&#39;t be blank"
    end

    test "a valid field carries no invalid marker" do
      html = render_component(&CoreComponents.input/1, name: "name", label: "Name", value: "x")
      refute html =~ "aria-invalid"
    end

    test "select and textarea use the same field style" do
      select =
        render_component(&CoreComponents.input/1,
          name: "rank",
          type: "select",
          options: ["Species"],
          value: "Species"
        )

      textarea =
        render_component(&CoreComponents.input/1, name: "notes", type: "textarea", value: nil)

      assert select =~ ~r{<select [^>]*class="oc-input\s*"}
      assert textarea =~ ~r{<textarea [^>]*class="oc-input\s*"}
    end

    test "a checkbox sits in the check label" do
      html =
        render_component(&CoreComponents.input/1,
          name: "published",
          type: "checkbox",
          label: "Published",
          value: true
        )

      assert html =~ ~s(<label class="oc-check">)
      assert html =~ "checked"
    end
  end

  describe "page/1" do
    test "sets the content in the frame by default" do
      html = render_component(&CoreComponents.page/1, inner_block: text_slot("Species"))

      assert html =~ ~s(<div class="oc-pg">)
      assert html =~ ~s(class="oc-pg-body oc-pg-frame")
      assert html =~ ~r{<div class="oc-pg-measure ?">\s*Species\s*</div>}
      refute html =~ "oc-pg-bleed"
      refute html =~ "oc-pg-head"
    end

    for width <- ~w(read form) do
      test "takes the #{width} measure" do
        html =
          render_component(&CoreComponents.page/1,
            width: unquote(width),
            inner_block: text_slot("About")
          )

        assert html =~ ~s(class="oc-pg-body oc-pg-#{unquote(width)}")
      end
    end

    test "runs the bleed full width above the framed content" do
      html =
        render_component(&CoreComponents.page/1,
          bleed: text_slot("Title page"),
          inner_block: text_slot("Contents")
        )

      assert html =~ ~r{<div class="oc-pg-bleed">\s*Title page\s*</div>\s*<div class="oc-pg-body}
    end

    test "sets the head across the frame, above the measure" do
      html =
        render_component(&CoreComponents.page/1,
          width: "form",
          head: text_slot("Log in"),
          inner_block: text_slot("Email")
        )

      assert html =~
               ~r{<div class="oc-pg-body oc-pg-form">\s*<div class="oc-pg-head">\s*Log in\s*</div>\s*<div class="oc-pg-measure ?">\s*Email\s*</div>}
    end
  end
end
