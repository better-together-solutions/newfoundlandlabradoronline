# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Api
    module V1
      # Receives a council meeting video found by the management tool (see scripts/meeting_recordings_sync.py) and
      # attaches it, with its captions, to the matching meeting. Platform managers, or a trusted OAuth application
      # granted a write scope, may call it.
      class MeetingRecordingsController < BetterTogether::Api::ApplicationController
        MAX_BYTES = 3.megabytes
        WRITE_SCOPES = %w[write write_events admin].freeze
        STATUSES = { meeting_not_found: :not_found, ambiguous_meeting: :conflict, video_on_other_meeting: :conflict,
                     meeting_has_other_recording: :conflict }.freeze

        before_action :require_trusted_oauth_application_or_platform_manager!
        before_action :require_write_scope!
        before_action :limit_body_size!
        skip_after_action :enforce_policy_use
        rescue_from(ActiveRecord::RecordInvalid) do |error|
          render json: { error: 'record_invalid', messages: error.record.errors.full_messages },
                 status: :unprocessable_content
        end

        def create
          result = Meetings::RecordingAttacher.new(
            video_id: params[:video_id], metadata: metadata, selector: selector, apply: !dry_run?
          ).call
          result.error? ? render_failure(result.error) : render_result(result)
        end

        private

        def metadata = params[:metadata].respond_to?(:to_unsafe_h) ? params[:metadata].to_unsafe_h : nil

        def selector = { source_id: params[:source_id], date: params[:date], body_key: params[:body_key] }

        def dry_run? = ActiveModel::Type::Boolean.new.cast(params[:dry_run]) == true

        def require_write_scope!
          return unless oauth2_authenticated?
          return if WRITE_SCOPES.any? { |scope| doorkeeper_token.scopes.exists?(scope) }

          render json: { error: 'insufficient_scope' }, status: :forbidden
        end

        def limit_body_size!
          return if request.content_length.to_i <= MAX_BYTES

          render json: { error: 'payload_too_large', max_bytes: MAX_BYTES }, status: :payload_too_large
        end

        def render_result(result)
          render json: { status: result.status, dry_run: dry_run?, meeting_id: result.meeting.id,
                         source_id: result.meeting.source_id, video_id: params[:video_id], captions: result.captions },
                 status: result.status == 'attached' ? :created : :ok
        end

        def render_failure(code)
          render json: { error: code.to_s }, status: STATUSES.fetch(code, :unprocessable_content)
        end
      end
    end
  end
end
