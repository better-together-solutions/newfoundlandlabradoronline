# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The council's meetings for one municipality: a timeline with a filter per kind of meeting.
  class MunicipalMeetingsController < ApplicationController
    include NewfoundlandLabradorOnline::ProvinceScoped

    helper NewfoundlandLabradorOnline::MunicipalitiesHelper

    before_action :load_municipality

    def index
      @meetings = council_meetings
      @categories = @meetings.filter_map(&:category).uniq.sort_by { |category| category.name.to_s }
    end

    def show
      @meeting = council_meeting
      @recording = @meeting.recordings.min_by(&:created_at)
      @caption = @recording&.caption
    end

    # The captions as a plain text download, one line per cue with its start time.
    def transcript
      caption = council_meeting.recordings.filter_map(&:caption).first
      raise ActiveRecord::RecordNotFound unless caption

      send_data caption.transcript_text, type: 'text/plain; charset=utf-8', disposition: 'attachment',
                                         filename: "council-meeting-#{params[:meeting_id]}.txt"
    end

    private

    def load_municipality
      settlement = BetterTogether::Geography::Settlement.friendly.find(params[:id])
      @municipality = NewfoundlandLabradorOnline::Civic::Municipality.for(settlement)
      raise ActiveRecord::RecordNotFound unless @municipality && settlement.state_id == @province.id

      authorize :municipality, :show?, policy_class: NewfoundlandLabradorOnline::MunicipalityPolicy
    end

    def council_meeting
      Meeting.where(body: @municipality.council).includes(:documents, recordings: :captions, event: :categories)
             .find(params[:meeting_id])
    end

    # Events, their slugs and categories are preloaded so the query count stays flat as meetings are added.
    def council_meetings
      Meeting.where(body: @municipality.council).newest_first
             .includes(:documents, :recordings, event: [:string_translations,
                                                        { categories: :string_translations }]).to_a
    end
  end
end
