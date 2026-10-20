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
end
