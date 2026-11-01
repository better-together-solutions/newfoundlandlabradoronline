# frozen_string_literal: true

# Dated municipal status and external identifiers for settlements (a place keeps one record across incorporation,
# amalgamation and renaming). Written in the CE table and naming convention so it can move to the gem as is.
class CreateBetterTogetherGeographySettlementStatusesAndIdentifiers < ActiveRecord::Migration[8.1]
  def change
    create_settlement_statuses unless table_exists?(:better_together_geography_settlement_statuses)
    create_settlement_identifiers unless table_exists?(:better_together_geography_settlement_identifiers)
  end

  private

  def create_settlement_statuses # rubocop:disable Metrics/MethodLength
    create_bt_table :geography_settlement_statuses do |t|
      t.references :settlement, type: :uuid, null: false, index: false,
                                foreign_key: { to_table: :better_together_geography_settlements }
      t.string :municipal_status, null: false, limit: 50
      t.string :name
      t.date :valid_from
      t.date :valid_to
      t.string :authority, null: false
      t.string :source_url
      t.string :license
      t.index %i[settlement_id valid_from], name: 'by_geography_settlement_status_dates'
      t.index :municipal_status, name: 'by_geography_settlement_municipal_status'
    end
  end

  def create_settlement_identifiers
    create_bt_table :geography_settlement_identifiers do |t|
      t.references :settlement, type: :uuid, null: false, index: true,
                                foreign_key: { to_table: :better_together_geography_settlements }
      t.string :scheme, null: false, limit: 50
      t.string :value, null: false
      t.index %i[scheme value], unique: true, name: 'by_geography_settlement_identifier_value'
      t.index %i[settlement_id scheme], unique: true, name: 'by_geography_settlement_identifier_scheme'
    end
  end
end
