# Modules being replaced (Heartwood.Guardrails.Retirements), checked by
# Oaks.GuardrailsTest: an entry fails while its old module and its
# replacement both exist. A task that builds a replacement adds its entry
# first, as its failing test, and deletes the old module in the same change;
# then the entry goes.
#
#   %{retire: OaksWeb.OldThing, replaced_by: OaksWeb.NewThing, why: "docs/plan.md, phase 2"}
[]
