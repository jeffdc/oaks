defmodule Oaks.GuardrailsTest do
  # DuplicateCode runs Credo, which toggles a global output switch: not async.
  use ExUnit.Case, async: false

  import Heartwood.Guardrails.Assertions

  test "UI code uses the component library", do: assert_ratchet(OaksWeb.Conformance)
  test "no new copied code", do: assert_ratchet(Heartwood.Guardrails.DuplicateCode)
  test "replaced code is deleted", do: assert_no_outstanding_retirements()

  describe "the git hooks" do
    test "dev/githooks/ holds heartwood's shim, as of the pinned tag" do
      shim = Path.join(Mix.Project.deps_paths()[:heartwood_guardrails], "hooks/app-shim")

      for hook <- ["pre-commit", "pre-push"] do
        assert File.read!("dev/githooks/#{hook}") == File.read!(shim),
               "dev/githooks/#{hook} isn't heartwood's hooks/app-shim: copy it again (its CHANGELOG.md says when)."
      end
    end

    # With HEARTWOOD_PATH set, the hooks use that checkout instead.
    test "HEARTWOOD_HOME in dev/guardrails/config.sh is where the package is" do
      [_, home] = Regex.run(~r/^HEARTWOOD_HOME=(\S+)$/m, File.read!("dev/guardrails/config.sh"))

      if System.get_env("HEARTWOOD_PATH") == nil do
        assert Path.expand(home) == Path.expand(Mix.Project.deps_paths()[:heartwood_guardrails])
      end
    end
  end
end
