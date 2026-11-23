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
    <.page width="read" class="space-y-s7">
      <:head>
        <.header>Privacy Policy</.header>
      </:head>

      <section>
        <.section_heading>Privacy-Protecting Analytics</.section_heading>
        <div class="prose-content">
          <p>
            The Oak Compendium uses a custom, self-hosted analytics system designed to respect
            visitor privacy while providing useful insights for site improvement. We do not use
            Google Analytics or any third-party tracking service.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>How It Works</.section_heading>
        <div class="prose-content">
          <p>
            We compute a daily visitor identifier as <code>SHA256(daily_salt &Vert; ip &Vert; user_agent)</code>, where
            the salt is a random secret generated each day and held only in server memory. The IP
            address and user-agent are read in memory only; neither is written to disk. Without
            the salt, the stored hash can't be reversed or matched against a guessed IP.
          </p>
          <p>
            A new salt is generated at midnight UTC and the old one is discarded, so every visitor
            identifier rotates daily. Yesterday's identifier cannot be reconstructed today, which
            makes cross-day tracking technically impossible.
          </p>
          <p>
            The implementation is open source. View the code on GitHub:
            <a
              href="https://github.com/jeffdc/oaks/blob/main/lib/oaks/analytics.ex"
              target="_blank"
              rel="noopener noreferrer"
            >analytics module</a>
            and <a
              href="https://github.com/jeffdc/oaks/blob/main/lib/oaks_web/plugs/analytics.ex"
              target="_blank"
              rel="noopener noreferrer"
            >analytics plug</a>.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>View Live Analytics</.section_heading>
        <div class="prose-content">
          <p>
            You can view real-time site analytics on the public <a href="/analytics">Analytics page</a>,
            which shows the same data collected using this privacy-protecting approach.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>What We Don't Store</.section_heading>
        <div class="prose-content">
          <ul>
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
        </div>
      </section>

      <section>
        <.section_heading>What We Do Collect</.section_heading>
        <div class="prose-content">
          <p>
            The following is recorded per page view and aggregated for statistical purposes only:
          </p>
          <ul>
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
              <strong>Daily-Rotating Visitor Hash:</strong>
              used to count unique daily visitors per page
            </li>
            <li><strong>Timestamp:</strong> when the page was visited</li>
          </ul>
        </div>
      </section>

      <section>
        <.section_heading>Data Retention</.section_heading>
        <div class="prose-content">
          <p>
            Individual page-view records are kept for 30 days. After that they are rolled up
            into daily totals (views and unique visitors per page, referring sites, and error
            counts) and deleted; only those daily totals are kept long-term. Because the only
            per-visit identifier is the daily-rotating hash, there is no way to connect visits
            across days or identify individual visitors at any point.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>No Third-Party Trackers</.section_heading>
        <div class="prose-content">
          <p>
            The Oak Compendium does not use Google Analytics, Facebook Pixel, or any other
            third-party tracking service. All analytics happen in this application, on our
            server, with the code shown above.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Authentication</.section_heading>
        <div class="prose-content">
          <p>
            The Oak Compendium has no public accounts and no sign-up: visitors never log in, and
            no personal data is collected from them. Only the site's author logs in, and the login
            cookies are never set for visitors.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Cookies</.section_heading>
        <div class="prose-content">
          <p>
            A standard Phoenix session cookie is used to carry the daily-rotating visitor hash
            between the initial page request and any client-side navigation that follows. It is
            not used for tracking, not shared with third parties, and contains no personal data.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>External Services</.section_heading>
        <div class="prose-content">
          <p>
            The Oak Compendium relies on the following external services:
          </p>
          <ul>
            <li><strong>Fly.io:</strong> application hosting</li>
            <li>
              <strong>AWS S3 (via Litestream):</strong>
              continuous database backup only; no visitor data is sent to S3
            </li>
          </ul>
        </div>
      </section>

      <section>
        <.section_heading>Changes to This Policy</.section_heading>
        <div class="prose-content">
          <p>
            We may update this privacy policy from time to time. Any changes will be posted on
            this page with an updated revision date below.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Contact</.section_heading>
        <div class="prose-content">
          <p>
            If you have questions about this privacy policy or our data practices, please <a
              href="https://github.com/jeffdc/oaks/issues"
              target="_blank"
              rel="noopener noreferrer"
            >open an issue on GitHub</a>.
          </p>
        </div>
      </section>

      <footer class="page-foot">Last updated: 2026-05-12</footer>
    </.page>
    """
  end
end
