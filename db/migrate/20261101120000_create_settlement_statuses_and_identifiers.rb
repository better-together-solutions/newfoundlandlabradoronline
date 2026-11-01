# frozen_string_literal: true

# Dated municipal status and external identifiers for settlements (a place keeps one record across incorporation,
# amalgamation and renaming).
class CreateSettlementStatusesAndIdentifiers < ActiveRecord::Migration[8.1]
  def change
    create_settlement_statuses unless table_exists?(:settlement_statuses)
    create_settlement_identifiers unless table_exists?(:settlement_identifiers)
  end

  private

  def create_settlement_statuses # rubocop:disable Metrics/MethodLength
    create_table :settlement_statuses, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :settlement, type: :uuid, null: false, index: false,
                                foreign_key: { to_table: :better_together_geography_settlements }
      t.string :municipal_status, null: false, limit: 50
      t.string :name
      t.date :valid_from
      t.date :valid_to
      t.string :authority, null: false
      t.string :source_url
      t.string :license
      t.index %i[settlement_id valid_from], name: 'index_settlement_statuses_on_settlement_and_valid_from'
      t.index :municipal_status
    end
  end

  def create_settlement_identifiers
    create_table :settlement_identifiers, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :settlement, type: :uuid, null: false, index: true,
                                foreign_key: { to_table: :better_together_geography_settlements }
      t.string :scheme, null: false, limit: 50
      t.string :value, null: false
      t.index %i[scheme value], unique: true, name: 'index_settlement_identifiers_on_scheme_and_value'
      t.index %i[settlement_id scheme], unique: true, name: 'index_settlement_identifiers_on_settlement_and_scheme'
    end
  end
end
