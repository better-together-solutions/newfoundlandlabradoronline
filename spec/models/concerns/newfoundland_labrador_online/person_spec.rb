# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Person do
  include RequestSpecHelper

  before { configure_host_platform }

  it "keeps a person's own community private even for a public profile" do
    person = BetterTogether::Person.create!(identifier: 'nl-mha-test-person', name: 'Test Person',
                                            privacy: 'public', locale: 'en')

    expect(person.community.privacy).to eq('private')
  end

  it 'sets a community made public again back to private on the next save' do
    person = BetterTogether::Person.create!(identifier: 'nl-mha-test-person', name: 'Test Person', locale: 'en')
    person.community.update_columns(privacy: 'public')
    person.update!(name: 'Renamed Person')

    expect(person.community.reload.privacy).to eq('private')
  end
end
