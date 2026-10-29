# frozen_string_literal: true

# Political parties (scoped to a jurisdiction: a provincial party is not its federal namesake), linked from candidacies.
# Party membership is a civic membership in the party's community.
class CreatePoliticalParties < ActiveRecord::Migration[8.1]
  def change
    create_political_parties unless table_exists?(:political_parties)
    add_party_reference(:candidacies)
  end

  private

  def create_political_parties # rubocop:disable Metrics/MethodLength
    create_table :political_parties, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.string :jurisdiction, null: false, limit: 50
      t.string :identifier, null: false, limit: 100
      t.string :name, null: false
      t.string :short_name, null: false
      t.string :color, limit: 7
      t.string :color_source
      t.string :wikipedia_page
      t.string :logo_source_url
      t.string :logo_license
      t.boolean :logo_non_free
      t.index %i[jurisdiction identifier], unique: true, name: 'index_political_parties_on_jurisdiction_and_identifier'
    end
  end

  def add_party_reference(table)
    return if column_exists?(table, :political_party_id)

    add_reference table, :political_party, type: :uuid, null: true, index: true, foreign_key: true
  end
end
