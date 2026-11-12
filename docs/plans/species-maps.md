Each species page shows the species' native range as highlighted administrative regions, at whatever granularity is known (country, state/province, county).

Done when a species detail page draws a map of its range from stored species-region associations.

Why this order: the boundary dataset fixes the region identifiers and granularity, so it is chosen first. The data model and the map component both build on those identifiers, and the species page needs both.

From the old species-maps epic (matters dc39, 847a, e54e, d037).
