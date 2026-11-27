# `mix credo --strict` runs Credo's defaults, as before this file: it has no
# "default" config. The "duplicates" config is copied code
# (Heartwood.Guardrails.DuplicateCode), held to
# test/support/duplicate_code_baseline.json by Oaks.GuardrailsTest rather than
# by `credo --strict`. See each block with: mix credo --config-name duplicates
%{
  configs: [
    %{
      name: "duplicates",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: %{
        enabled: [
          {Credo.Check.Design.DuplicatedCode, [mass_threshold: 40]}
        ]
      }
    }
  ]
}
