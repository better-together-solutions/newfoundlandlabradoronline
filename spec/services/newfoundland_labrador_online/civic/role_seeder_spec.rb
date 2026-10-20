# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::RoleSeeder do
  include RequestSpecHelper

  before { configure_host_platform }

  it 'seeds inert roles idempotently', :aggregate_failures do
    expect { described_class.call }.to change(BetterTogether::Role, :count).by(described_class::ROLES.size)
    expect { described_class.call }.not_to change(BetterTogether::Role, :count)

    role = BetterTogether::Role.find_by(identifier: 'director')
    expect(role.resource_permissions).to be_empty
    expect(Mobility.with_locale(:fr) { role.name }).to eq('Administrateur')
  end
end
