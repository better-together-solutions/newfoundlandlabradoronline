# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::MunicipalContactLoader do
  include RequestSpecHelper

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(path: write(roster), apply: true).call
  end

  after { Dir[Rails.root.join("tmp/contact_spec_#{Process.pid}_*.json")].each { |file| FileUtils.rm_f(file) } }

  let!(:settlement) { create(:geography_settlement, name: 'Testville') }
  let(:roster) do
    { 'councils' => [{ 'settlement' => settlement.slug, 'council_name' => 'Testville Council', 'officials' => [] }] }
  end
  let(:council) { NewfoundlandLabradorOnline::Civic::Municipality.for(settlement).council }

  def write(packet)
    Rails.root.join("tmp/contact_spec_#{Process.pid}_#{SecureRandom.hex(4)}.json").tap do |file|
      File.write(file, packet.to_json)
    end
  end

  def entry(slug: settlement.slug, url: 'https://www.youtube.com/@testville')
    { 'settlement' => slug,
      'addresses' => [{ 'label' => 'main', 'line1' => '1 Main Street', 'city_name' => 'Testville',
                        'postal_code' => 'A1A 1A1', 'physical' => true, 'postal' => true }],
      'phone_numbers' => [{ 'number' => '709-555-0100', 'label' => 'work' },
                          { 'number' => '709-555-0101', 'label' => 'Report an issue (24/7)' }],
      'email_addresses' => [{ 'email' => 'hall@example.test', 'label' => 'work' }],
      'social_media_accounts' => [{ 'platform_name' => 'YouTube', 'handle' => '@testville', 'url' => url }] }
  end

  def run(apply: true, **)
    described_class.new(path: write('contacts' => [entry(**)]), apply:).call
  end

  it 'writes nothing on a dry run', :aggregate_failures do
    expect(run(apply: false).created.size).to eq(5)
    expect(BetterTogether::PhoneNumber.count + BetterTogether::SocialMediaAccount.count).to eq(0)
  end

  # rubocop:disable-next RSpec/ExampleLength
  it 'attaches public records to the council contact detail', :aggregate_failures do
    run

    expect(council.phone_numbers.find_by(number: '709-555-0100')).to have_attributes(label: 'work', privacy: 'public')
    expect(council.phone_numbers.map(&:display_label)).to include('Report an issue (24/7)')
    expect(council.email_addresses.first.email).to eq('hall@example.test')
    expect(council.addresses.first).to have_attributes(line1: '1 Main Street', privacy: 'public')
    expect(council.social_media_accounts.first).to have_attributes(platform_name: 'YouTube', handle: '@testville')
  end

  it 'is idempotent and updates a changed value', :aggregate_failures do
    run

    expect(run.unchanged.size).to eq(5)
    expect(run(url: 'https://www.youtube.com/@renamed').updated.size).to eq(1)
    expect(council.social_media_accounts.count).to eq(1)
  end

  it 'reports a settlement with no council' do
    expect(run(slug: create(:geography_settlement, name: 'Nowhere').slug).missing_councils.size).to eq(1)
  end
end
