# frozen_string_literal: true

# Public meetings of civic bodies (councils first) with the documents the host publishes. The category colour column
# meeting categories use comes from the Community Engine gem's own migration.
class CreateCouncilMeetings < ActiveRecord::Migration[8.1]
  def up
    create_meetings unless table_exists?(:meetings)
    create_meeting_documents unless table_exists?(:meeting_documents)
  end

  def down
    drop_table :meeting_documents if table_exists?(:meeting_documents)
    drop_table :meetings if table_exists?(:meetings)
  end

  private

  def create_meetings # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    create_table :meetings, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :body, type: :uuid, null: false, index: true,
                          foreign_key: { to_table: :better_together_communities }
      t.references :event, type: :uuid, index: { unique: true },
                           foreign_key: { to_table: :better_together_events, on_delete: :nullify }
      t.string :kind, null: false, default: 'council'
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :body_key
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.string :location
      t.string :status, null: false, default: 'scheduled'
      t.string :portal_url
      t.jsonb :details, null: false, default: {}
      t.string :source_checksum, limit: 64
      t.datetime :fetched_at
      t.timestamps
    end
    add_index :meetings, %i[source source_id], unique: true
    add_index :meetings, %i[body_id starts_at]
  end

  def create_meeting_documents
    create_table :meeting_documents, id: :uuid do |t|
      t.references :meeting, type: :uuid, null: false, index: true, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :format, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.timestamps
    end
    add_index :meeting_documents, %i[meeting_id kind format url], unique: true, name: 'idx_meeting_documents_unique'
  end
end
