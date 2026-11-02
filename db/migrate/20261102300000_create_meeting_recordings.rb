# frozen_string_literal: true

# Recordings of public meetings (a video on a provider) and their captions, kept as timestamped cues.
class CreateMeetingRecordings < ActiveRecord::Migration[8.1]
  def up
    create_recordings unless table_exists?(:meeting_recordings)
    create_captions unless table_exists?(:recording_captions)
  end

  def down
    drop_table :recording_captions if table_exists?(:recording_captions)
    drop_table :meeting_recordings if table_exists?(:meeting_recordings)
  end

  private

  def create_recordings # rubocop:disable Metrics/MethodLength
    create_table :meeting_recordings, id: :uuid do |t|
      t.references :meeting, type: :uuid, null: false, index: true, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :provider_ref, null: false
      t.string :watch_url, null: false
      t.string :embed_url, null: false
      t.string :live_status, null: false, default: 'past'
      t.string :match_method, null: false, default: 'source_link'
      t.datetime :scheduled_for
      t.datetime :published_at
      t.integer :duration_seconds
      t.datetime :fetched_at
      t.timestamps
    end
    add_index :meeting_recordings, %i[meeting_id provider provider_ref], unique: true,
                                                                         name: 'idx_meeting_recordings_unique'
  end

  def create_captions # rubocop:disable Metrics/MethodLength
    create_table :recording_captions, id: :uuid do |t|
      t.references :recording, type: :uuid, null: false, index: true,
                               foreign_key: { to_table: :meeting_recordings, on_delete: :cascade }
      t.string :language, null: false
      t.string :format, null: false, default: 'vtt'
      t.string :source, null: false
      t.text :body, null: false
      t.jsonb :cues, null: false, default: []
      t.string :raw_checksum, limit: 64, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :recording_captions, %i[recording_id language], unique: true
  end
end
