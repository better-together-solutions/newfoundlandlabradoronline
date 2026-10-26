# frozen_string_literal: true

# Builders for civic-role specs: communities of each subtype, roles and dated memberships.
module CivicHelpers
  def civic_community(klass = BetterTogether::Community, **attrs)
    klass.create!({ name: "Body #{SecureRandom.hex(4)}", identifier: "body-#{SecureRandom.hex(8)}",
                    privacy: 'private', host: false, protected: false }.merge(attrs))
  end

  def civic_role(identifier = 'civic_office')
    BetterTogether::Role.find_by(identifier:, resource_type: 'BetterTogether::Community') ||
      create(:better_together_role, :community_role, identifier:)
  end

  def join(person, community, role: civic_role, **attrs)
    BetterTogether::PersonCommunityMembership.create!({ member: person, joinable: community, role:,
                                                        status: 'active' }.merge(attrs))
  end

  def associate(source, target, relation, **attrs)
    NewfoundlandLabradorOnline::CommunityAssociation.create!({ source_community: source, target_community: target,
                                                               relation: }.merge(attrs))
  end
end

RSpec.configure { |config| config.include CivicHelpers }
