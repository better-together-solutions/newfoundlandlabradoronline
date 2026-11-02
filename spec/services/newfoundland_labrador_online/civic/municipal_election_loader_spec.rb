# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::MunicipalElectionLoader do
  include RequestSpecHelper

  before do
    configure_host_platform
    settlement
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(path: write(roster), apply: true).call
  end

  after { Dir[Rails.root.join('tmp/municipal_spec_*.json')].each { |file| FileUtils.rm_f(file) } }

  let(:settlement) { create(:geography_settlement, name: 'Testville') }
  let(:roster) do
    { 'councils' => [{ 'settlement' => settlement.slug, 'council_name' => 'Testville Council',
                       'officials' => [{ 'name' => 'Ann Mayor', 'role' => 'head', 'title' => 'Mayor' },
                                       { 'name' => 'Bo Coun', 'role' => 'member', 'title' => 'Councillor' }] }] }
  end
  let(:results) do
    { 'elections' => [{ 'settlement' => settlement.slug, 'date' => '2025-10-02',
                        'contests' => [
                          { 'office' => 'mayor',
                            'candidates' => [{ 'name' => 'Ann Mayor', 'votes' => 90, 'elected' => true },
                                             { 'name' => 'Cy Lose', 'votes' => 10 }] },
                          { 'office' => 'councillor', 'seats_available' => 2,
                            'candidates' => [{ 'name' => 'Bo Coun', 'votes' => 50, 'elected' => true },
                                             { 'name' => 'Di Ner', 'acclaimed' => true, 'elected' => true }] }
                        ] }] }
  end

  def write(packet)
    Rails.root.join("tmp/municipal_spec_#{SecureRandom.hex(4)}.json").tap { |file| File.write(file, packet.to_json) }
  end

  def run(apply)
    described_class.new(path: write(results), apply:).call
  end

  it 'writes nothing on a dry run', :aggregate_failures do
    expect(run(false)).to have_attributes(elections: 1, contests: 2, candidacies: 4)
    expect(NewfoundlandLabradorOnline::Election.count).to eq(0)
  end

  it 'records results and links elected candidates to their offices', :aggregate_failures do
    result = run(true)

    expect(result).to have_attributes(linked: 2, unlinked: ['Di Ner'])
    mayor = NewfoundlandLabradorOnline::Candidacy.find_by(candidate_name: 'Ann Mayor')
    expect(mayor.member.name).to eq('Ann Mayor')
    expect(mayor.electoral_contest).to have_attributes(office: 'mayor', winners: [mayor], total_votes: 100)
  end

  it 'accepts an acclaimed candidate with no votes or party' do
    run(true)

    expect(NewfoundlandLabradorOnline::Candidacy.find_by(candidate_name: 'Di Ner')).to be_valid
  end

  it 'is idempotent' do
    run(true)
    counts = -> { [NewfoundlandLabradorOnline::Election.count, NewfoundlandLabradorOnline::Candidacy.count] }

    expect { run(true) }.not_to(change(&counts))
  end
end
