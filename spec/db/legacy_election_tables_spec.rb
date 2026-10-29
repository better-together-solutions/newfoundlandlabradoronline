# frozen_string_literal: true

require 'rails_helper'

# Who held a seat or a party membership is a civic membership. The earlier tables must not come back.
# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'Legacy election tables' do
  let(:legacy_names) { /ElectedTerm|PartyMembership\b|elected_terms|[:'"]party_memberships\b/ }
  let(:sources) do
    patterns = %w[app/**/* lib/**/* config/**/* scripts/**/* spec/**/*].map { |glob| Rails.root.join(glob).to_s }
    files = patterns.flat_map { |pattern| Dir[pattern] } << Rails.root.join('db/seeds.rb').to_s
    files.select { |file| File.file?(file) && file.match?(/\.(rb|rake|erb|yml)\z/) }.reject { |file| file == __FILE__ }
  end

  it 'has neither table', :aggregate_failures do
    connection = ActiveRecord::Base.connection

    expect(connection.table_exists?(:elected_terms)).to be(false)
    expect(connection.table_exists?(:party_memberships)).to be(false)
  end

  it 'is not mentioned by application code, tasks or specs' do
    offenders = sources.select { |file| File.read(file).match?(legacy_names) }

    expect(offenders).to be_empty
  end
end
