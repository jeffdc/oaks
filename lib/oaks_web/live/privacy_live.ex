defmodule OaksWeb.PrivacyLive do
  @moduledoc """
  Public privacy policy explaining the Oak Compendium's self-hosted,
  privacy-respecting analytics. Mirrors gallformers' /privacy page,
  adapted to oaks (SQLite, no Auth0, no image hosting on S3).
  """

  use OaksWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Privacy")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <h2
        class="text-3xl font-bold mb-8"
        style="font-family: var(--font-serif); color: var(--color-forest-800, #165132);"
      >
        Privacy Policy
      </h2>

      <section class="mb-8">
        <h3 class="section-title">Privacy-Protecting Analytics</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The Oak Compendium uses a custom, self-hosted analytics system designed to respect
          visitor privacy while providing useful insights for site improvement. We do not use
          Google Analytics or any third-party tracking service.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">How It Works</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          We compute a daily visitor identifier as <code>SHA256(today_date &Vert; ip &Vert; user_agent)</code>. The IP address and
          user-agent are read in memory only; neither is written to disk. The resulting hash is
          a one-way fingerprint and cannot be reversed to recover your IP.
        </p>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          Because the date is part of the hash input, every visitor identifier rotates at
          midnight UTC. Yesterday's identifier cannot be reconstructed today, which makes
          cross-day tracking technically impossible.
        </p>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The implementation is open source. View the code on GitHub:
          <a
            href="https://github.com/jeffdc/oaks/blob/main/lib/oaks/analytics.ex"
            target="_blank"
            rel="noopener noreferrer"
          >
            analytics module
          </a>
          and <a
            href="https://github.com/jeffdc/oaks/blob/main/lib/oaks_web/plugs/analytics.ex"
            target="_blank"
            rel="noopener noreferrer"
          >analytics plug</a>.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">View Live Analytics</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          You can view real-time site analytics on the public <a href="/analytics">Analytics page</a>,
          which shows the same data collected using this privacy-protecting approach.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">What We Don't Store</h3>
        <ul
          class="list-disc pl-6 space-y-2"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          <li><strong>IP Addresses:</strong> never written to disk or logged</li>
          <li>
            <strong>User Agents:</strong>
            read in memory only to compute the daily hash and detect bots; not stored
          </li>
          <li><strong>Tracking Cookies:</strong> none are set</li>
          <li>
            <strong>Cross-Session Data:</strong>
            the daily-rotating hash makes it technically impossible to correlate visits across days
          </li>
          <li>
            <strong>Personal Information:</strong>
            no email addresses, names, or other identifying information
          </li>
        </ul>
      </section>

      <section class="mb-8">
        <h3 class="section-title">What We Do Collect</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The following is recorded per page view and aggregated for statistical purposes only:
        </p>
        <ul
          class="list-disc pl-6 space-y-2"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          <li>
            <strong>Page Paths:</strong>
            which pages are visited (for example, "/about" or "/species/quercus-alba")
          </li>
          <li><strong>HTTP Status Codes:</strong> so we can find and fix broken links (404s)</li>
          <li>
            <strong>Referrer Hosts:</strong>
            the host portion of the HTTP Referer header (for example, "google.com"); never the full URL or path
          </li>
          <li>
            <strong>Daily-Rotating Visitor Hash:</strong> used to count unique daily visitors per page
          </li>
          <li><strong>Timestamp:</strong> when the page was visited</li>
        </ul>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Data Retention</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          Aggregate analytics data is retained indefinitely so we can understand long-term
          trends. Because the only per-visit identifier is the daily-rotating hash, there is
          no way to connect visits across days or identify individual visitors regardless of
          retention.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">No Third-Party Trackers</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The Oak Compendium does not use Google Analytics, Facebook Pixel, or any other
          third-party tracking service. All analytics happen in this application, on our
          server, with the code shown above.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Authentication</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The Oak Compendium has no public user accounts and no login flow for visitors.
          Write access to the database is gated by an API key used only by the site author;
          no personal data is collected from visitors at any point.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Cookies</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          A standard Phoenix session cookie is used to carry the daily-rotating visitor hash
          between the initial page request and any client-side navigation that follows. It is
          not used for tracking, not shared with third parties, and contains no personal data.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">External Services</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The Oak Compendium relies on the following external services:
        </p>
        <ul
          class="list-disc pl-6 space-y-2"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          <li><strong>Fly.io:</strong> application hosting</li>
          <li>
            <strong>AWS S3 (via Litestream):</strong>
            continuous database backup only; no visitor data is sent to S3
          </li>
        </ul>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Changes to This Policy</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          We may update this privacy policy from time to time. Any changes will be posted on
          this page with an updated revision date below.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Contact</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          If you have questions about this privacy policy or our data practices, please <a
            href="https://github.com/jeffdc/oaks/issues"
            target="_blank"
            rel="noopener noreferrer"
          >open an issue on GitHub</a>.
        </p>
      </section>

      <footer
        class="mt-12 pt-6 text-center"
        style="border-top: 1px solid var(--color-border);"
      >
        <span
          class="text-xs"
          style="color: var(--color-text-tertiary); font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;"
        >
          Last updated: 2026-05-12
        </span>
      </footer>
    </div>
    """
  end
end
