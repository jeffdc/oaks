# Req is a dev/test-only dependency, so the task is compiled only where Req is
# available. It runs from CI's dev shell and local checkouts, never a release.
if Code.ensure_loaded?(Req) do
  defmodule Mix.Tasks.SmokeTest do
    @moduledoc """
    Run smoke tests against an Oaks deployment.

    ## Usage

        mix smoke_test https://oaks.fly.dev
        mix smoke_test https://oakcompendium.org

    ## Test Suite

    - Phase 1: Health check and the public API's 410
    - Phase 2: Resource discovery (a species from the list)
    - Phase 3: Public pages
    - Phase 4: Search functionality
    - Phase 5: Static assets

    Exits with code 0 if all tests pass, 1 if any fail.
    """

    use Mix.Task

    @shortdoc "Run smoke tests against a deployment"

    @timeout 10_000

    def run([base_url]) do
      execute(base_url)
    end

    def run(_) do
      print_usage()
    end

    @spec execute(String.t()) :: no_return()
    defp execute(base_url) do
      {:ok, _} = Application.ensure_all_started(:req)

      IO.puts("Running smoke tests against #{base_url}")
      IO.puts("")

      client = Req.new(base_url: base_url, receive_timeout: @timeout, retry: false)

      # Phase 1: Core health & the public API's gate
      results =
        []
        |> run_and_accumulate(client, "Health check", "/health", &check_health/1)
        |> run_and_accumulate(
          client,
          "API offline",
          "/api/v1/stats",
          &check_api_offline/1,
          status: 410
        )

      # Phase 2: Resource discovery, from the public page
      {results, species_name} =
        run_and_accumulate_with_value(
          results,
          client,
          "Discover species",
          "/species",
          &discover_species/1
        )

      # Phase 3: Public pages
      results = run_and_accumulate(results, client, "Home page", "/", &check_home/1)

      results =
        if species_name do
          run_and_accumulate(
            results,
            client,
            "Species detail page",
            "/species/#{species_name}",
            &check_species_page/1
          )
        else
          results
        end

      results =
        results
        |> run_and_accumulate(client, "Species list page", "/species", &check_page_not_empty/1)
        |> run_and_accumulate(client, "Taxonomy page", "/taxonomy", &check_page_not_empty/1)
        |> run_and_accumulate(client, "Articles page", "/articles", &check_page_not_empty/1)
        |> run_and_accumulate(client, "Sources page", "/sources", &check_page_not_empty/1)

      # Phase 4: Search
      results =
        run_and_accumulate(
          results,
          client,
          "Search UI",
          "/search?q=alba",
          &check_page_not_empty/1
        )

      # Phase 5: Static assets
      results =
        case extract_asset_paths(client) do
          {:ok, css_path, js_path} ->
            results
            |> run_and_accumulate(client, "Static CSS", css_path, &check_not_empty/1)
            |> run_and_accumulate(client, "Static JS", js_path, &check_not_empty/1)

          {:error, _} ->
            run_and_accumulate(results, client, "Static assets", "/", &check_has_assets/1)
        end

      print_summary(Enum.reverse(results))
      exit_with_code(results)
    end

    defp run_and_accumulate(results, client, name, path, check_fn, opts \\ []) do
      {result, _value} = run_check(client, name, path, check_fn, opts)
      [result | results]
    end

    defp run_and_accumulate_with_value(results, client, name, path, check_fn) do
      {result, value} = run_check(client, name, path, check_fn, [])
      {[result | results], value}
    end

    defp run_check(client, name, path, check_fn, opts) do
      expected =
        case Keyword.get(opts, :status, 200..299) do
          status when is_integer(status) -> status..status
          statuses -> statuses
        end

      case Req.get(client, url: path) do
        {:ok, %{status: status, body: body}} ->
          if status in expected do
            process_check_result(name, path, check_fn.(body))
          else
            reason = "HTTP #{status}"
            IO.puts("x #{name} (#{path}) - #{reason}")
            {{:fail, name, reason}, nil}
          end

        {:error, error} ->
          reason = format_error(error)
          IO.puts("x #{name} (#{path}) - #{reason}")
          {{:fail, name, reason}, nil}
      end
    end

    defp process_check_result(name, path, {:ok, value}) do
      IO.puts("ok #{name} (#{path})#{if value, do: " -> #{value}", else: ""}")
      {{:pass, name}, value}
    end

    defp process_check_result(name, path, {:error, reason}) do
      IO.puts("x #{name} (#{path}) - #{reason}")
      {{:fail, name, reason}, nil}
    end

    defp format_error(%{reason: :timeout}), do: "connection timeout"
    defp format_error(%{reason: :econnrefused}), do: "connection refused"
    defp format_error(%{reason: reason}), do: inspect(reason)
    defp format_error(error), do: inspect(error)

    # Check functions

    defp check_health(body) when is_binary(body) do
      if String.contains?(body, "ok"),
        do: {:ok, nil},
        else: {:error, "body does not contain 'ok'"}
    end

    defp check_api_offline(body) when is_map(body) do
      case body do
        %{"error" => message} when is_binary(message) ->
          if String.contains?(message, "https://oakcompendium.org"),
            do: {:ok, nil},
            else: {:error, "the error doesn't point at the site"}

        _ ->
          {:error, "missing the error message"}
      end
    end

    defp check_api_offline(_), do: {:error, "response is not JSON"}

    defp discover_species(body) when is_binary(body) do
      names =
        ~r{href="/species/([^"/?#]+)"}
        |> Regex.scan(body, capture: :all_but_first)
        |> List.flatten()
        |> Enum.reject(&(&1 == "new"))

      case names do
        [name | _] -> {:ok, name}
        [] -> {:error, "no species link on the species list"}
      end
    end

    defp discover_species(_), do: {:error, "response is not a page"}

    defp check_home(body) when is_binary(body) do
      if String.contains?(body, "Oak Compendium"),
        do: {:ok, nil},
        else: {:error, "missing 'Oak Compendium'"}
    end

    defp check_species_page(body) when is_binary(body) do
      if String.length(body) > 500, do: {:ok, nil}, else: {:error, "page appears empty"}
    end

    defp check_page_not_empty(body) when is_binary(body) do
      if String.length(body) > 100, do: {:ok, nil}, else: {:error, "page appears empty"}
    end

    defp check_not_empty(body) when is_binary(body) do
      if String.length(body) > 100, do: {:ok, nil}, else: {:error, "file appears empty"}
    end

    defp check_has_assets(body) when is_binary(body) do
      has_css = body =~ ~r/\/assets\/css\/app-[a-f0-9]+\.css/
      has_js = body =~ ~r/\/assets\/js\/app-[a-f0-9]+\.js/

      if has_css and has_js, do: {:ok, nil}, else: {:error, "missing expected asset links"}
    end

    defp extract_asset_paths(client) do
      case Req.get(client, url: "/") do
        {:ok, %{status: 200, body: body}} when is_binary(body) ->
          css_path = Regex.run(~r/(\/assets\/css\/app-[a-f0-9]+\.css[^"']*)/, body)
          js_path = Regex.run(~r/(\/assets\/js\/app-[a-f0-9]+\.js[^"']*)/, body)

          case {css_path, js_path} do
            {[_, css], [_, js]} -> {:ok, css, js}
            _ -> {:error, "could not extract asset paths"}
          end

        _ ->
          {:error, "could not fetch home page"}
      end
    end

    defp print_summary(results) do
      IO.puts("")
      total = length(results)

      passed =
        Enum.count(results, fn
          {:pass, _} -> true
          _ -> false
        end)

      failed = total - passed
      IO.puts("#{total} checks, #{passed} passed, #{failed} failed")
    end

    @spec exit_with_code(list()) :: no_return()
    defp exit_with_code(results) do
      has_failures =
        Enum.any?(results, fn
          {:fail, _, _} -> true
          _ -> false
        end)

      if has_failures, do: System.halt(1), else: System.halt(0)
    end

    defp print_usage do
      IO.puts("""
      Usage: mix smoke_test <base_url>

      Example:
        mix smoke_test https://oaks.fly.dev
        mix smoke_test https://oakcompendium.org
      """)
    end
  end
end
