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

    test "danger is the ink plate" do
      html =
        render_component(&CoreComponents.button/1,
          variant: "danger",
          inner_block: text_slot("Delete species")
        )

      assert html =~ ~s(<button class="oc-btn oc-btn-danger">)
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

  describe "header/1" do
    test "puts the title line and subtitle in the text column and the actions beside it" do
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

      assert html =~
               ~r{<div class="oc-title-text">\s*<div class="oc-title-line">\s*<h1>\s*Sources\s*</h1>\s*</div>\s*<p class="oc-title-sub">Every work the Compendium cites.</p>\s*</div>}

      assert html =~ ~s(<div class="oc-title-actions"><button>Add</button></div>)
      refute html =~ "oc-title-meta"
    end

    test "sets each meta entry as one item on the title's line, after the title" do
      assigns = %{draft: false}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header id="t">
          Shumard oak
          <:meta>Species</:meta>
          <:meta :if={@draft}>Draft</:meta>
          <:meta><strong>LC</strong></:meta>
          <:subtitle>A red oak.</:subtitle>
        </CoreComponents.header>
        """)

      assert html =~ ~r{<header class="oc-title\s*" id="t">}

      assert html =~
               ~r{<div class="oc-title-line">\s*<h1>\s*Shumard oak\s*</h1>\s*<div class="oc-title-meta">\s*<span>Species</span><span><strong>LC</strong></span>\s*</div>\s*</div>\s*<p class="oc-title-sub">}

      refute html =~ "Draft"
      refute html =~ "oc-title-actions"
    end
  end

  describe "edit_menu/1" do
    test "is a compact Edit disclosure holding links and event buttons" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.edit_menu id="m">
          <:item navigate="/species/alba/edit" id="edit-btn">Edit species</:item>
          <:item href="/old" method="delete">Remove</:item>
          <:item click="request_delete" values={%{id: 7}} id="delete-btn">Delete species</:item>
        </CoreComponents.edit_menu>
        """)

      assert html =~ ~r{<details id="m" class="oc-edit-menu\s*" data-menu[^>]*phx-mounted=}
      assert html =~ ~r{<summary class="oc-btn oc-btn-compact">\s*Edit\s*</summary>}
      assert html =~ ~s(<ul class="oc-edit-menu-list">)
      assert html =~ ~r{<a [^>]*href="/species/alba/edit"}
      assert html =~ ~r{<a [^>]*id="edit-btn"}
      assert html =~ ~r{<a [^>]*data-method="delete"}

      # The event button keeps the menu's trigger on the focus stack, so a
      # dialog it opens hands focus back to the trigger when it closes.
      [button] = Regex.run(~r{<button type="button" id="delete-btn"[^>]*>}, html)
      assert button =~ ~s(phx-value-id="7")
      assert button =~ "push_focus"
      assert button =~ "#m &gt; summary"
      assert button =~ "request_delete"
    end

    test "takes another label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.edit_menu id="m" label="Add">
          <:item navigate="/species/new">New species</:item>
        </CoreComponents.edit_menu>
        """)

      assert html =~ ~r{<summary class="oc-btn oc-btn-compact">\s*Add\s*</summary>}
    end

    test "quiet is a small text trigger named for its object" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.edit_menu id="m" quiet aria_label="Edit Agrifoliae">
          <:item navigate="/taxonomy/1/edit">Edit subsection</:item>
        </CoreComponents.edit_menu>
        """)

      assert html =~ ~r{<details id="m" class="oc-edit-menu oc-edit-menu-quiet"}
      assert html =~ ~r{<summary class="oc-edit-menu-trigger" aria-label="Edit Agrifoliae">}
      refute html =~ "oc-btn"
    end
  end

  describe "table/1" do
    test "renders a ruled table with row headers, a voice column and stacking labels" do
      assigns = %{rows: [%{trait: "Buds", oak_compendium: "buds looks glabrous"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="marks" rows={@rows} stack>
          <:col :let={row} label="Trait" row_header>{row.trait}</:col>
          <:col :let={row} label="Oak Compendium" voice>{row.oak_compendium}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~r{<div class="oc-table-wrap oc-table-stack\s*">}
      assert html =~ ~s(<table class="oc-table">)
      assert html =~ ~s(<th scope="col">Trait</th>)
      assert html =~ ~r{<th scope="row"[^>]*>\s*Buds\s*</th>}

      assert html =~
               ~r{<td data-label="Oak Compendium" class="oc-voice\s*">\s*buds looks glabrous}
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

  describe "modal/1" do
    test "renders a titled dialog with its notes and one close control before the action" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="confirm">
          <:title>Delete species</:title>
          Delete it?
          <:note>This can't be undone.</:note>
          <:actions>
            <CoreComponents.button variant="danger" id="go">Delete species</CoreComponents.button>
          </:actions>
        </CoreComponents.modal>
        """)

      assert html =~ ~s(role="dialog")
      assert html =~ ~s(aria-modal="true")
      assert html =~ ~s(aria-labelledby="confirm-title")
      assert html =~ ~r{<h2 id="confirm-title" class="oc-modal-title">\s*Delete species\s*</h2>}
      assert html =~ ~r{<div class="oc-modal-note">\s*This can't be undone.\s*</div>}
      assert html =~ "oc-modal-panel"

      # One close control, first in the actions row, then the action.
      assert [_one] = Regex.scan(~r{id="confirm-cancel"}, html)
      assert html =~ ~r{id="confirm-cancel"[^>]*>\s*Cancel\s*</button>\s*<button[^>]*id="go"}s
      refute html =~ "Close <kbd>"
      # Hidden until shown from the browser.
      refute html =~ ~r{phx-mounted="[^"]*\[}
    end

    test "with show it opens when it mounts, and cancel names the close control" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="cant" show cancel="Close">
          <:title>Can't delete source</:title>
          3 species have data from it.
        </CoreComponents.modal>
        """)

      assert html =~ ~r{<div id="cant" phx-mounted="[^"]*show}
      assert html =~ ~r{id="cant-cancel"[^>]*>\s*Close\s*</button>}
    end
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
    test "sets the content in the centred column by default" do
      html = render_component(&CoreComponents.page/1, inner_block: text_slot("Species"))

      assert html =~ ~s(<div class="oc-pg">)
      assert html =~ ~s(class="oc-pg-body oc-pg-column")
      assert html =~ ~r{<div class="oc-pg-measure ?">\s*Species\s*</div>}
      refute html =~ "oc-pg-bleed"
      refute html =~ "oc-pg-head"
    end

    for width <- ~w(read form frame) do
      test "takes the #{width} width" do
        html =
          render_component(&CoreComponents.page/1,
            width: unquote(width),
            inner_block: text_slot("About")
          )

        assert html =~ ~s(class="oc-pg-body oc-pg-#{unquote(width)}")
      end
    end

    test "runs the bleed full width above the content" do
      html =
        render_component(&CoreComponents.page/1,
          bleed: text_slot("Title page"),
          inner_block: text_slot("Contents")
        )

      assert html =~ ~r{<div class="oc-pg-bleed">\s*Title page\s*</div>\s*<div class="oc-pg-body}
    end

    test "sets the head across the page's width, above the content" do
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
