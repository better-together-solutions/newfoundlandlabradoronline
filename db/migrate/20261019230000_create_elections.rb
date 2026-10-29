# frozen_string_literal: true

# Elections, one contest per district per election, and candidacies. Who held a seat is a civic membership.
class CreateElections < ActiveRecord::Migration[8.1]
  def change
    create_elections unless table_exists?(:elections)
    create_electoral_contests unless table_exists?(:electoral_contests)
    create_candidacies unless table_exists?(:candidacies)
  end

  private

  def create_elections # rubocop:disable Metrics/MethodLength
    create_table :elections, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.string :jurisdiction, null: false, limit: 50
      t.date :held_on, null: false
      t.string :source_url
      t.integer :source_revid
      t.string :source_sha256, limit: 64
      t.string :license
      t.index %i[jurisdiction held_on], unique: true
    end
  end

  def create_electoral_contests
    create_table :electoral_contests, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :election, type: :uuid, null: false, index: false, foreign_key: true
      t.references :region, type: :uuid, null: false, index: true,
                            foreign_key: { to_table: :better_together_geography_regions }
      t.decimal :turnout, precision: 5, scale: 2
      t.index %i[election_id region_id], unique: true
    end
  end

  def create_candidacies # rubocop:disable Metrics/MethodLength
    create_table :candidacies, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :electoral_contest, type: :uuid, null: false, index: true, foreign_key: true
      t.string :candidate_name, null: false
      t.string :party_name, null: false
      t.integer :votes, null: false
      t.decimal :vote_share, precision: 5, scale: 2
      t.boolean :elected, null: false, default: false
      t.string :wikipedia_path
      t.index %i[electoral_contest_id candidate_name], unique: true, name: 'index_candidacies_on_contest_and_name'
    end
  end
end
