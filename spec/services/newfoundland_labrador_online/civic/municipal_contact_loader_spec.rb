# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::MunicipalSocialAccountLoader do
  include RequestSpecHelper

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(path: write(roster), apply: true).call
  end

  after { Dir[Rails.root.join("tmp/social_spec_#{Process.pid}_*.json")].each { |file| FileUtils.rm_f(file) } }

  let!(:settlement) { create(:geography_settlement, name: 'Testville') }
  let(:roster) do
    { 'councils' => [{ 'settlement' => settlement.slug, 'council_name' => 'Testville Council', 'officials' => [] }] }
  end
  let(:url) { 'https://www.youtube.com/@testville' }
  let(:council) { NewfoundlandLabradorOnline::Civic::Municipality.for(settlement).council }

  def write(packet)
    Rails.root.join("tmp/social_spec_#{Process.pid}_#{SecureRandom.hex(4)}.json").tap do |file|
      File.write(file, packet.to_json)
    end
  end

  def run(apply: true, slug: settlement.slug, address: url)
    entry = { 'settlement' => slug, 'platform' => 'YouTube', 'handle' => '@testville', 'url' => address }
    described_class.new(path: write('accounts' => [entry]), apply:).call
  end

  it 'writes nothing on a dry run', :aggregate_failures do
    expect(run(apply: false).created).to eq(["#{settlement.slug}/YouTube"])
    expect(BetterTogether::SocialMediaAccount.count).to eq(0)
  end

  it 'attaches a public account to the council contact detail', :aggregate_failures do
    run

    account = council.social_media_accounts.first
    expect(account).to have_attributes(platform_name: 'YouTube', url:, handle: '@testville', privacy: 'public')
  end

  it 'is idempotent and updates a changed url', :aggregate_failures do
    run

    expect(run.unchanged).to eq(["#{settlement.slug}/YouTube"])
    expect(run(address: 'https://www.youtube.com/@renamed').updated).to eq(["#{settlement.slug}/YouTube"])
    expect(council.social_media_accounts.count).to eq(1)
  end

  it 'reports a settlement with no council' do
    expect(run(slug: create(:geography_settlement, name: 'Nowhere').slug).missing_councils.size).to eq(1)
  end
end
