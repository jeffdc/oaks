defmodule OaksWeb.PhotoViewer do
  @moduledoc """
  The photo viewer: a shared component, built here to move back to
  gallformers (docs/species-photos-plan.md, Phase 6). Keep it
  self-contained: this module uses only `Phoenix.Component`, its script is
  the `PhotoViewer` hook in assets/js/app.js, and its styles are the
  Photo viewer block (`pv-` classes) in assets/css/system/components.css,
  themed by `--pv-*` custom properties. Nothing in its markup, script or
  styles knows about the site around it.

  Design: design/prototype/photo-viewer.css and photo-viewer.js (the
  stage, caption, credit and thumbnail rail), with the full-size view,
  swipe and details dialog of gallformers' `photo_viewer/1`.
  """
  use Phoenix.Component

  @doc """
  Renders a set of photos: one on the stage, with its caption, then its
  credit (creator, license and source link); under it a rail of
  thumbnails that shows a few at a time (`--pv-visible`, 5; 6 on phones)
  with step buttons that page through the rest, and a count. Clicking the
  stage photo opens it full size; Details opens a dialog listing the
  photo's attribution.

  The server renders every photo's slide, full-size figure and details;
  the `PhotoViewer` hook shows the current one. Left and Right keys move
  photo by photo while focus is in the viewer (its dialogs included), a
  horizontal swipe on the photo moves on touch screens, and moves wrap.
  Escape, Close or a click outside closes a dialog, and focus returns to
  what opened it. With `on_change`, every move pushes that event with
  `%{"index" => i}`. When the photos change, the viewer is rebuilt and
  shows the first one again.

  With one photo there is no rail and no count; with none, only the
  `empty` line (hidden on phones).

  `photos` are maps with atom keys:

    * `src` (required): the stage image, a medium size
    * `thumb`: the rail image, a small size (defaults to `src`)
    * `full`: the full-size view's image, loaded when first shown
      (defaults to `src`)
    * `alt` (defaults to "Photo n of <label>")
    * `caption`, `creator`, `license`, `licenselink`
    * `sourcelink` and `source_label`: where the photo comes from, and the
      link's words (defaults to "Source")
    * `reserved`: all rights reserved: the creator is marked © and the
      license set on its own line in bold
    * `attribution`, `uploader`, `lastchangedby`: shown in the details
      when given

  ## Examples

      <.photo_viewer id="species-photos" label="Quercus shumardii" photos={[
        %{src: medium, thumb: small, full: large, caption: "Bark",
          creator: "janedoe", license: "CC-BY-NC",
          sourcelink: "https://www.inaturalist.org/observations/1",
          source_label: "iNaturalist observation"}
      ]} />
  """
  attr :id, :string, required: true
  attr :photos, :list, required: true
  attr :label, :string, required: true, doc: "what the photos show, for alt text and labels"
  attr :empty, :string, default: "No photos yet.", doc: "the line shown when there are none"
  attr :on_change, :string, default: nil, doc: "an event pushed with the index on every move"
  attr :class, :any, default: nil, doc: "theming (`--pv-*`) and layout only"

  def photo_viewer(assigns) do
    photos = assigns.photos

    assigns =
      assign(assigns,
        indexed: Enum.with_index(photos),
        count: length(photos),
        # A new id for new photos: LiveView replaces the ignored element
        # and the hook starts again on the new set.
        key: :erlang.phash2(photos)
      )

    ~H"""
    <div id={@id} class={["pv", @class]}>
      <p :if={@count == 0} class="pv-empty">{@empty}</p>
      <div
        :if={@count > 0}
        id={"#{@id}-#{@key}"}
        class="pv-in"
        phx-hook="PhotoViewer"
        phx-update="ignore"
        role="region"
        aria-roledescription="carousel"
        aria-label={"Photos of #{@label}"}
        data-count={@count}
        data-event={@on_change}
      >
        <figure
          :for={{photo, i} <- @indexed}
          class="pv-stage"
          data-slide={i}
          hidden={i != 0}
          aria-label={@count > 1 && "Photo #{i + 1} of #{@count}"}
        >
          <button
            type="button"
            class="pv-frame"
            data-open
            data-stage
            aria-label={"#{photo_alt(photo, i, @label)}, full size"}
          >
            <img
              src={field(photo, :src)}
              alt={photo_alt(photo, i, @label)}
              loading={if i == 0, do: "eager", else: "lazy"}
              draggable="false"
            />
          </button>
          <figcaption>
            <p :if={field(photo, :caption)} class="pv-cap">{field(photo, :caption)}</p>
            <.credit photo={photo} />
          </figcaption>
        </figure>

        <div :if={@count > 1} class="pv-rail" data-fits={@count <= 5}>
          <button
            type="button"
            class="pv-step pv-step-prev"
            data-page="-1"
            aria-label="Earlier photos"
          />
          <ol class="pv-thumbs" data-thumbs>
            <li :for={{photo, i} <- @indexed}>
              <button
                type="button"
                class="pv-thumb"
                data-go={i}
                aria-current={to_string(i == 0)}
                aria-label={"Photo #{i + 1} of #{@count}"}
              >
                <img src={field(photo, :thumb) || field(photo, :src)} alt="" loading="lazy" />
              </button>
            </li>
          </ol>
          <button type="button" class="pv-step pv-step-next" data-page="1" aria-label="Later photos" />
        </div>

        <div class="pv-foot">
          <span :if={@count > 1} class="pv-count" data-counter>1 / {@count}</span>
          <button type="button" class="pv-link" data-open-details>Details</button>
        </div>

        <dialog class="pv-lightbox" data-lightbox aria-label={"Photos of #{@label}, full size"}>
          <div class="pv-lb-bar">
            <span :if={@count > 1} class="pv-count" data-counter>1 / {@count}</span>
            <button type="button" class="pv-close" data-close aria-label="Close" />
          </div>
          <div class="pv-lb-stage" data-stage>
            <figure
              :for={{photo, i} <- @indexed}
              class="pv-lb-figure"
              data-full={i}
              hidden={i != 0}
            >
              <img
                data-src={field(photo, :full) || field(photo, :src)}
                alt={photo_alt(photo, i, @label)}
                draggable="false"
              />
              <figcaption>
                <p :if={field(photo, :caption)} class="pv-cap">{field(photo, :caption)}</p>
                <.credit photo={photo} />
              </figcaption>
            </figure>
            <button
              :if={@count > 1}
              type="button"
              class="pv-lb-step pv-step-prev"
              data-prev
              aria-label="Previous photo"
            />
            <button
              :if={@count > 1}
              type="button"
              class="pv-lb-step pv-step-next"
              data-next
              aria-label="Next photo"
            />
          </div>
        </dialog>

        <dialog class="pv-details" data-details aria-labelledby={"#{@id}-details-title"}>
          <h2 id={"#{@id}-details-title"} class="pv-details-title">Photo details</h2>
          <div class="pv-details-body">
            <dl :for={{photo, i} <- @indexed} data-info={i} hidden={i != 0}>
              <div :if={@count > 1}>
                <dt>Photo</dt>
                <dd>{i + 1} of {@count}</dd>
              </div>
              <div :for={{label, value} <- details(photo)}>
                <dt>{label}</dt>
                <dd>{value}</dd>
              </div>
            </dl>
          </div>
          <div class="pv-details-actions">
            <button type="button" class="pv-button" data-close autofocus>Close</button>
          </div>
        </dialog>
      </div>
    </div>
    """
  end

  attr :photo, :map, required: true

  # The credit line: creator, license, source link. All rights reserved
  # puts © before the creator and the license, in bold, on its own line.
  defp credit(assigns) do
    assigns = assign(assigns, reserved: Map.get(assigns.photo, :reserved, false) == true)

    ~H"""
    <p class="pv-credit">
      <span :if={field(@photo, :creator)}>
        {if @reserved, do: "© "}<b>{field(@photo, :creator)}</b>
      </span>
      <span :if={!@reserved && field(@photo, :license)}><.license photo={@photo} /></span>
      <span :if={field(@photo, :sourcelink)}>
        <a href={field(@photo, :sourcelink)} target="_blank" rel="noopener noreferrer">
          {field(@photo, :source_label) || "Source"}
        </a>
      </span>
      <strong :if={@reserved && field(@photo, :license)} class="pv-reserved">
        {field(@photo, :license)}
      </strong>
    </p>
    """
  end

  attr :photo, :map, required: true

  defp license(assigns) do
    ~H"""
    <a
      :if={field(@photo, :licenselink)}
      href={field(@photo, :licenselink)}
      target="_blank"
      rel="noopener noreferrer"
    >{field(@photo, :license)}</a><span :if={!field(@photo, :licenselink)}>{field(@photo, :license)}</span>
    """
  end

  # The details dialog's rows for one photo, the empty ones left out.
  defp details(photo) do
    [
      {"Caption", field(photo, :caption)},
      {"Creator", field(photo, :creator)},
      {"License", field(photo, :license) && license(%{photo: photo})},
      {"Attribution", field(photo, :attribution)},
      {"Source", field(photo, :sourcelink) && source_link(%{photo: photo})},
      {"Uploader", field(photo, :uploader)},
      {"Last changed by", field(photo, :lastchangedby)}
    ]
    |> Enum.filter(fn {_label, value} -> value end)
  end

  attr :photo, :map, required: true

  defp source_link(assigns) do
    ~H"""
    <a href={field(@photo, :sourcelink)} target="_blank" rel="noopener noreferrer">
      {field(@photo, :source_label) || field(@photo, :sourcelink)}
    </a>
    """
  end

  # A photo's text field; blank is nil.
  defp field(photo, key) do
    case Map.get(photo, key) do
      value when value in [nil, ""] -> nil
      value -> to_string(value)
    end
  end

  defp photo_alt(photo, i, label), do: field(photo, :alt) || "Photo #{i + 1} of #{label}"
end
