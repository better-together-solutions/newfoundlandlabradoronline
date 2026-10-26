# frozen_string_literal: true

# Provisions the legislature and party communities and converts elected terms and party memberships into dated
# memberships. Fails closed: any conversion error or parity difference aborts the migration (and the deploy).
class BackfillCivicRoles < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:elected_terms) && table_exists?(:party_memberships)

    civic = NewfoundlandLabradorOnline::Civic
    result = civic::Backfill.call(write: true)
    raise "Civic backfill errors: #{result.errors.first(5).join('; ')}" if result.errors.any?

    differences = civic::ParityReport.call
    raise "Civic parity differences: #{differences.first(5).join('; ')}" if differences.any?
  end

  def down
    # The converted memberships are additive; the old tables are untouched, so there is nothing to undo.
  end
end
