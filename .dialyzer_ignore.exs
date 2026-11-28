# Dialyzer false positives to skip (dialyxir `ignore_warnings`).
#
# Ecto.Multi.new/0 returns `%Multi{}`, whose `names: MapSet.new()` default is
# a literal struct, so OTP 28's dialyzer reports `call_without_opaque` when
# the result is piped straight into an Ecto.Multi function. The code is
# correct; Ecto 3.14.3 still defines the struct this way.
[
  {"lib/oaks/accounts.ex", :call_without_opaque},
  {"lib/oaks/species.ex", :call_without_opaque}
]
