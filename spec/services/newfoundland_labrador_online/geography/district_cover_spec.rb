# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::DistrictCover do
  include RequestSpecHelper

  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }
  let(:district) { NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook') }
  let(:record) { district.reload }
  let(:jpeg) { Rails.root.join('spec/fixtures/files/cover.jpg') }

  def attach(bytes: 'generated-bytes', filename: 'nl-ped-corner-brook.jpg')
    described_class.call(region: district, io: StringIO.new(bytes), filename:)
  end

  def upload_custom
    record.cover_image.attach(io: StringIO.new('custom-bytes'), filename: 'mine.jpg', content_type: 'image/jpeg')
    record.save!
  end

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path:).call
  end

  it 'stores the image as the default and as the cover, marked generated', :aggregate_failures do
    expect(attach.status).to eq(:attached)
    expect(record.cover_image.download).to eq('generated-bytes')
    expect(record.default_cover_image.download).to eq('generated-bytes')
    expect(record).to be_generated_cover
  end

  it 'replaces an earlier generated cover' do
    attach(bytes: 'old')
    attach(bytes: 'new')

    expect(record.cover_image.download).to eq('new')
  end

  it 'never replaces an uploaded cover but refreshes the default', :aggregate_failures do
    upload_custom

    expect(attach.status).to eq(:kept_custom)
    expect(record.cover_image.download).to eq('custom-bytes')
    expect(record.default_cover_image.download).to eq('generated-bytes')
  end

  it 'restores the default when the uploaded cover is removed', :aggregate_failures do
    attach
    upload_custom
    record.update!(remove_cover_image: '1')

    expect(record.reload.cover_image.download).to eq('generated-bytes')
    expect(record).to be_generated_cover
  end
end
