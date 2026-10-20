# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::CommunityAssociation do
  # rubocop:disable RSpec/ExampleLength
  include RequestSpecHelper

  before { configure_host_platform }

  let(:person) { create(:better_together_person) }
  let(:parent) { civic_community(NewfoundlandLabradorOnline::LegislatureCommunity) }
  let(:child) { civic_community(NewfoundlandLabradorOnline::CommitteeCommunity) }

  it 'takes kind and participation from the registry', :aggregate_failures do
    link = associate(parent, child, 'committee_of')

    expect(link.kind).to eq('hierarchy')
    expect(link.participation).to eq('members_only')
  end

  it 'rejects unknown relations, self links and cycles', :aggregate_failures do
    associate(parent, child, 'committee_of')

    expect(described_class.new(source_community: parent, target_community: child, relation: 'nope')).not_to be_valid
    expect(described_class.new(source_community: parent, target_community: parent,
                               relation: 'committee_of')).not_to be_valid
    expect(described_class.new(source_community: child, target_community: parent,
                               relation: 'committee_of')).not_to be_valid
  end

  it 'does not make a child more public than its parent unless open', :aggregate_failures do
    public_child = civic_community(NewfoundlandLabradorOnline::CommitteeCommunity, privacy: 'public')

    expect(described_class.new(source_community: parent, target_community: public_child,
                               relation: 'committee_of')).not_to be_valid
    expect(described_class.new(source_community: parent, target_community: public_child, relation: 'committee_of',
                               participation: 'open')).to be_valid
  end

  describe 'navigation' do
    it 'finds parents, children, ancestors, descendants and peers', :aggregate_failures do
      sub = civic_community(NewfoundlandLabradorOnline::CommitteeCommunity)
      partner = civic_community(NewfoundlandLabradorOnline::PartyCommunity)
      associate(parent, child, 'committee_of')
      associate(child, sub, 'committee_of')
      associate(parent, partner, 'coalition_partner')

      expect(child.parents).to contain_exactly(parent)
      expect(parent.children).to contain_exactly(child)
      expect(parent.descendants).to contain_exactly(child, sub)
      expect(sub.ancestors).to contain_exactly(child, parent)
      expect(partner.peers).to contain_exactly(parent)
    end

    it 'respects the time-box', :aggregate_failures do
      associate(parent, child, 'committee_of', starts_on: Date.new(2020, 1, 1), ends_on: Date.new(2021, 1, 1))

      expect(parent.children(on: Date.new(2020, 6, 1))).to contain_exactly(child)
      expect(parent.children(on: Date.new(2022, 1, 1))).to be_empty
    end
  end

  describe 'eligibility' do
    it 'is open with no associations' do
      expect(child.eligibility_for(person)).to eq(:open)
    end

    it 'members_only needs a current membership in the source', :aggregate_failures do
      associate(parent, child, 'committee_of')

      expect(child.eligibility_for(person)).to eq(:ineligible)
      join(person, parent)
      expect(child.eligibility_for(person)).to eq(:member)
    end

    it 'treats one eligibility group as any-of and groups as all-of', :aggregate_failures do
      party = civic_community(NewfoundlandLabradorOnline::PartyCommunity)
      partner = civic_community(NewfoundlandLabradorOnline::PartyCommunity)
      cabinet = civic_community(NewfoundlandLabradorOnline::ExecutiveCommunity)
      associate(parent, cabinet, 'drawn_from', eligibility_group: 'legislature')
      associate(party, cabinet, 'governing_party', eligibility_group: 'government')
      associate(partner, cabinet, 'governing_party', eligibility_group: 'government')

      join(person, parent)
      expect(cabinet.eligibility_for(person)).to eq(:ineligible)
      join(person, partner)
      expect(cabinet.eligibility_for(person)).to eq(:member)
    end

    it 'members_and_invited needs an invitation or appointment from outsiders', :aggregate_failures do
      associate(parent, child, 'committee_of', participation: 'members_and_invited')

      expect(child.eligibility_for(person)).to eq(:invitation_required)
      expect(child.eligibility_for(person, invited: true)).to eq(:invited)
      join(person, parent)
      expect(child.eligibility_for(person)).to eq(:member)
    end

    it 'open participation does not privilege members' do
      associate(parent, child, 'committee_of', participation: 'open')

      expect(child.eligibility_for(person)).to eq(:open)
    end

    it 'enforces eligibility when joining and allows an appointment', :aggregate_failures do
      associate(parent, child, 'committee_of', participation: 'members_and_invited')

      expect { join(person, child) }.to raise_error(ActiveRecord::RecordInvalid, /not eligible/)

      membership = BetterTogether::PersonCommunityMembership.new(member: person, joinable: child, role: civic_role,
                                                                 status: 'active')
      membership.build_mandate(kind: 'appointed')
      expect(membership).to be_valid
    end
  end

  it 'covers the NLFC example: a representing seat needs membership in the co-op', :aggregate_failures do
    federation = civic_community(NewfoundlandLabradorOnline::OrganizationCommunity)
    board = civic_community(NewfoundlandLabradorOnline::OrganizationCommunity)
    coop = civic_community(NewfoundlandLabradorOnline::OrganizationCommunity)
    associate(coop, federation, 'member_of', role: 'full')
    seat = NewfoundlandLabradorOnline::CommunitySeat.create!(community: board, name: 'Co-op seat',
                                                             kind: 'representing', represents_community: coop)
    membership = BetterTogether::PersonCommunityMembership.new(member: person, joinable: board,
                                                               role: civic_role('director'), status: 'active',
                                                               starts_at: Time.zone.local(2024, 1, 1))
    membership.build_mandate(kind: 'elected', seat:)

    expect(membership).not_to be_valid
    join(person, coop)
    expect(membership).to be_valid
  end
  # rubocop:enable RSpec/ExampleLength
end
