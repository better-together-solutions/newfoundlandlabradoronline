# Election tables replaced by the civic model

Until October 2026 the district member and party history lived in two host tables, `elected_terms` (one row per
member per district per election) and `party_memberships` (dated party rows). The civic roles work moved both into
dated community memberships with mandates (a seat for the district, the candidacy that conferred it, start and end
reasons). A one-off migration converted the production rows and was checked row by row against the old tables before
anything read the new model. The old tables were then dropped by `DropLegacyCivicTables`, which refuses to run while
any row lacks a civic counterpart. New installs never create them: `nlo:electoral:seed` loads the data packet straight
into the civic model.
