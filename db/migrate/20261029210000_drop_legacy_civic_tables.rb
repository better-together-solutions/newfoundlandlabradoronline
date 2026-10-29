# frozen_string_literal: true

# Drops the election tables the civic model replaced. Does nothing where they do not exist (new installs). Refuses to
# drop while any row has no counterpart in the civic model, so a release that fails here leaves the old code serving.
class DropLegacyCivicTables < ActiveRecord::Migration[8.1]
  CANDIDACY = 'NewfoundlandLabradorOnline::Candidacy'

  def up
    ensure_converted
    drop_table :elected_terms, if_exists: true
    drop_table :party_memberships, if_exists: true
  end

  def down
    create_elected_terms unless table_exists?(:elected_terms)
    create_party_memberships unless table_exists?(:party_memberships)
  end

  private

  def ensure_converted
    missing = { elected_terms: unconverted_terms, party_memberships: unconverted_party_memberships }
    missing = missing.select { |table, count| table_exists?(table) && count.positive? }
    return if missing.empty?

    raise "Cannot drop legacy tables, rows without a civic counterpart: #{missing.inspect}"
  end

  def unconverted_terms
    return 0 unless table_exists?(:elected_terms)

    select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM elected_terms t WHERE NOT EXISTS (
        SELECT 1 FROM membership_mandates m WHERE m.conferred_by_type = '#{CANDIDACY}' AND m.conferred_by_id = t.candidacy_id)
    SQL
  end

  def unconverted_party_memberships
    return 0 unless table_exists?(:party_memberships)

    select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM party_memberships pm JOIN political_parties p ON p.id = pm.political_party_id WHERE NOT EXISTS (
        SELECT 1 FROM better_together_person_community_memberships c
        WHERE c.joinable_id = p.community_id AND c.member_id = pm.person_id
          AND c.starts_at >= pm.started_on - 1 AND c.starts_at < pm.started_on + 2)
    SQL
  end

  def create_elected_terms # rubocop:disable Metrics/MethodLength
    create_table :elected_terms, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :person, type: :uuid, null: false, index: true, foreign_key: { to_table: :better_together_people }
      t.references :region, type: :uuid, null: false, index: true,
                            foreign_key: { to_table: :better_together_geography_regions }
      t.references :election, type: :uuid, null: false, index: true, foreign_key: true
      t.references :candidacy, type: :uuid, null: false, index: false, foreign_key: true
      t.references :political_party, type: :uuid, null: true, index: true, foreign_key: true
      t.string :office, null: false, default: 'mha', limit: 50
      t.string :party_name, null: false
      t.date :started_on, null: false
      t.date :ended_on
      t.string :end_reason, limit: 50
      t.index %i[region_id election_id office], unique: true, name: 'index_elected_terms_on_seat_and_election'
      t.index :candidacy_id, unique: true
    end
  end

  def create_party_memberships # rubocop:disable Metrics/MethodLength
    create_table :party_memberships, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :person, type: :uuid, null: false, index: true, foreign_key: { to_table: :better_together_people }
      t.references :political_party, type: :uuid, null: false, index: true, foreign_key: true
      t.date :started_on, null: false
      t.date :ended_on
      t.string :start_reason, limit: 50
      t.string :end_reason, limit: 50
      t.string :source_url
      t.index %i[person_id political_party_id started_on], unique: true,
                                                           name: 'index_party_memberships_on_person_party_start'
    end
  end
end
