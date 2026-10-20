# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader do
  include RequestSpecHelper

  let(:district_path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }
  let(:path) { Rails.root.join('spec/fixtures/nl_regions/two_elections.json') }
  let(:corner_brook) { NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook') }

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path: district_path).call
  end

  describe 'first load' do
    let!(:result) { described_class.new(path:).call }

    it 'loads elections, contests and candidacies and reports unmatched districts', :aggregate_failures do
      expect(result.to_h.except(:missing_districts)).to eq(elections: 2, contests: 3, candidacies: 5, terms: 3)
      expect(result.missing_districts).to eq(['Nowhere'])
    end

    it 'matches district names despite dashes and accents' do
      humber = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-humber-gros-morne')

      holdings = NewfoundlandLabradorOnline::Civic::Roster.district_history(humber)

      expect(holdings.map { |holding| holding.person.name }).to eq(['Mike Goosney'])
    end

    it 'makes one person per member with a term per election, ending when the next begins', :aggregate_failures do
      terms = NewfoundlandLabradorOnline::Civic::Roster.district_history(corner_brook).reverse

      expect(terms.map { |term| term.person.name }).to eq(['Gerry Byrne', 'Jim Parsons'])
      expect(terms.first.ended_on).to eq(Date.new(2025, 10, 14))
      expect(terms.last.ended_on).to be_nil
    end
  end

  it 'is idempotent' do
    described_class.new(path:).call
    counts = -> { [NewfoundlandLabradorOnline::Candidacy.count, BetterTogether::PersonCommunityMembership.count, BetterTogether::Person.count] }

    expect { described_class.new(path:).call }.not_to(change(&counts))
  end

  it 'loads the full packet twice without overlapping re-elected terms' do
    full = NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader
    full.new(path: Rails.root.join('db/data/nl_regions/provincial_electoral_districts_2015.geojson')).call
    2.times { described_class.new.call }

    expect(NewfoundlandLabradorOnline::Civic::Roster.current_holdings.size).to eq(40)
  end
end
