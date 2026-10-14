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

  it 'knows the Corner Brook Online community and the Corner Brook settlement, and no others', :aggregate_failures do
    community = ->(identifier) { BetterTogether::Community.new(identifier:) }
    settlement = ->(identifier) { BetterTogether::Geography::Settlement.new(identifier:) }

    expect(described_class.slug_for(community.call('corner-brook-online'))).to eq('corner-brook')
    expect(described_class.slug_for(settlement.call('corner-brook'))).to eq('corner-brook')
    expect([described_class.slug_for(community.call('corner-brook')), described_class.slug_for(nil)]).to eq([nil, nil])
  end

  it 'returns nothing for an unknown slug' do
    expect(described_class.frame('nowhere')).to be_nil
  end

  it 'fetches a frame and makes it a 1920x1080 JPEG', :aggregate_failures do
    stub_source(ok)
    frame = described_class.frame('corner-brook')
    image = Vips::Image.new_from_buffer(frame.bytes, '')

    expect(Marcel::MimeType.for(StringIO.new(frame.bytes))).to eq('image/jpeg')
    expect([image.width, image.height, frame.etag.present?]).to eq([1920, 1080, true])
  end

  describe 'capture time' do
    let(:with_exif) { File.binread(Rails.root.join('spec/fixtures/files/frame_with_exif.jpg')) }

    it 'is read from the EXIF DateTimeOriginal in camera local time' do
      stub_source(success(with_exif))

      expected = Time.find_zone('America/St_Johns').local(2026, 10, 14, 18, 44, 45)

      expect(described_class.frame('corner-brook').captured_at).to eq(expected)
    end

    it 'is nil when the frame has no EXIF' do
      stub_source(ok)

      expect(described_class.frame('corner-brook').captured_at).to be_nil
    end
  end

  it 'peeks at the cache without fetching', :aggregate_failures do
    expect(described_class.peek('corner-brook')).to be_nil
    stub_source(ok)
    described_class.frame('corner-brook')

    expect(described_class.peek('corner-brook')).to be_present
    expect(Net::HTTP).to have_received(:start).once
  end

  it 'compresses the frame well under the cover size limit' do
    stub_source(ok)

    expect(described_class.frame('corner-brook').bytes.bytesize).to be < 700_000
  end

  describe 'the 16:9 crop' do
    def crop_of(width, height)
      Tempfile.create(['frame', '.png']) do |file|
        Vips::Image.black(width, height).write_to_file(file.path)
        described_class.send(:crop_box, file.path)
      end
    end

    it 'takes full width, 3 percent off the top, like the post covers' do
      expect(crop_of(3280, 2464)).to eq([0, 73, 3280, 1845])
    end

    it 'keeps the full height of a frame wider than 16:9' do
      expect(crop_of(2000, 500)).to eq([0, 0, 889, 500])
    end
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
