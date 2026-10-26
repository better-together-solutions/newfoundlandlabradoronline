# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentry configuration' do # rubocop:disable RSpec/DescribeClass
  let(:config) { Sentry.configuration }

  it 'does not report SystemExit from rails runner scripts' do
    expect(config.exception_class_allowed?(SystemExit.new)).to be(false)
  end

  it 'still reports ordinary errors' do
    expect(config.exception_class_allowed?(RuntimeError.new('boom'))).to be(true)
  end
end
