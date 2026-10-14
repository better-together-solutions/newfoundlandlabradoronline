# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::LiveImage do
  include ActiveSupport::Testing::TimeHelpers

  let(:png) do
    Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:ok) { success(png) }

  before do
    allow(Rails).to receive(:cache).and_return(cache)
  end

  def success(body)
    instance_double(Net::HTTPSuccess, body:, code: '200').tap do |response|
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end
  end

  def stub_source(response)
    allow(Net::HTTP).to receive(:start).and_return(response)
  end

  def failure(code = '500')
    instance_double(Net::HTTPServerError, code:, body: '').tap do |response|
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    end
  end

  it 'knows the Corner Brook Online community and no other', :aggregate_failures do
    community = ->(identifier) { instance_double(BetterTogether::Community, identifier:) }

    expect(described_class.slug_for(community.call('corner-brook-online'))).to eq('corner-brook')
    expect(described_class.slug_for(community.call('other'))).to be_nil
    expect(described_class.slug_for(nil)).to be_nil
  end

  it 'returns nothing for an unknown slug' do
    expect(described_class.frame('nowhere')).to be_nil
  end

  it 'fetches a frame and crops it to a 1280x720 JPEG', :aggregate_failures do
    stub_source(ok)
    frame = described_class.frame('corner-brook')
    image = Vips::Image.new_from_buffer(frame.bytes, '')

    expect(Marcel::MimeType.for(StringIO.new(frame.bytes))).to eq('image/jpeg')
    expect([image.width, image.height, frame.etag.present?]).to eq([1280, 720, true])
  end

  it 'serves the cached frame within a minute without another request', :aggregate_failures do
    stub_source(ok)
    first = described_class.frame('corner-brook')
    second = described_class.frame('corner-brook')

    expect(Net::HTTP).to have_received(:start).once
    expect(second.etag).to eq(first.etag)
  end

  it 'refreshes once the frame is older than a minute' do
    stub_source(ok)
    described_class.frame('corner-brook')

    travel_to(2.minutes.from_now) { described_class.frame('corner-brook') }

    expect(Net::HTTP).to have_received(:start).twice
  end

  it 'keeps serving the last good frame when the source fails', :aggregate_failures do
    stub_source(ok)
    good = described_class.frame('corner-brook')
    stub_source(failure)

    stale = travel_to(2.minutes.from_now) { described_class.frame('corner-brook') }

    expect(stale.etag).to eq(good.etag)
  end

  it 'returns nothing when the source has never worked' do
    stub_source(failure)

    expect(described_class.frame('corner-brook')).to be_nil
  end

  it 'rejects content that is not a JPEG or PNG' do
    stub_source(success('{"error":"not found"}'))

    expect(described_class.frame('corner-brook')).to be_nil
  end

  it 'treats a network error as a failed refresh' do
    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

    expect(described_class.frame('corner-brook')).to be_nil
  end
end
