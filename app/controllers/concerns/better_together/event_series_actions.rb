# frozen_string_literal: true

module BetterTogether
  # Web side of cancelling or deleting an event series: the confirmation panel on the series page sends
  # +session_disposition+ (cancel, delete or promote) and the series' sessions are settled with it. Without a choice
  # nothing changes and the person is told why. Prepended to EventsController.
  module EventSeriesActions
    def update
      return super unless settling_series?

      authorize_resource
      settle_series { @resource.cancel_series!(sessions: params[:session_disposition]) }
    end

    def destroy
      return super unless @resource.series? && @resource.sessions.any?

      authorize_resource
      settle_series(redirect: events_path) { @resource.destroy_series!(sessions: params[:session_disposition]) }
    end

    private

    def settling_series?
      @resource.series? && params[:settle] == 'cancel'
    end

    def settle_series(redirect: nil)
      yield
      redirect_to redirect || event_path(@resource), notice: t('better_together.events.series.settled')
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
      redirect_to event_path(@resource), alert: @resource.errors.full_messages.to_sentence
    end
  end
end
