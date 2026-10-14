# frozen_string_literal: true

# The contract every record in NewfoundlandLabradorOnline::LocatableModels must meet. The including
# spec supplies `record` (a saved record with no location).
RSpec.shared_examples 'a locatable record' do
  let(:settlement) { private_settlement("place-#{SecureRandom.hex(3)}") }
  let(:other_settlement) { private_settlement("other-#{SecureRandom.hex(3)}") }
  let(:model) { record.class.base_class }

  # The factory pins its community public, so the host platform must allow public records.
  def private_settlement(identifier)
    create(:geography_settlement, identifier:)
  end

  def place_inside(place)
    address = create(:better_together_address)
    BetterTogether::Geography::LocatableLocation.create!(locatable: address, location: place)
    address
  end

  it 'is listed in the onboarding registry' do
    expect(NewfoundlandLabradorOnline::LocatableModels.models).to include(model)
  end

  it 'has no settlement until one is set', :aggregate_failures do
    expect(record.settlement_identifier).to be_nil
    expect(record.effective_location).to be_nil
  end

  it 'is located at a settlement by identifier', :aggregate_failures do
    record.update!(settlement_identifier: settlement.identifier)

    expect(record.reload.settlement_identifier).to eq(settlement.identifier)
    expect(record.effective_location).to eq(settlement)
  end

  it 'accepts the identifier in any case' do
    record.update!(settlement_identifier: settlement.identifier.upcase)

    expect(record.reload.settlement_identifier).to eq(settlement.identifier)
  end

  it 'moves to another settlement without a second location row', :aggregate_failures do
    record.update!(settlement_identifier: settlement.identifier)
    record.update!(settlement_identifier: other_settlement.identifier)

    expect(record.reload.settlement_identifier).to eq(other_settlement.identifier)
    expect(BetterTogether::Geography::LocatableLocation.where(locatable: record).count).to eq(1)
  end

  it 'clears the location with a blank identifier' do
    record.update!(settlement_identifier: settlement.identifier)
    record.update!(settlement_identifier: nil)

    expect(record.reload.location).to be_nil
  end

  it 'rejects an unknown identifier without creating anything', :aggregate_failures do
    record.settlement_identifier = 'nowhere'

    expect(record).not_to be_valid
    expect(record.errors[:settlement_identifier]).to be_present
    expect { record.valid? }.not_to change(BetterTogether::Geography::Settlement, :count)
  end

  describe '.located_in' do
    it 'finds records located at the settlement and not at another', :aggregate_failures do
      record.update!(settlement_identifier: settlement.identifier)

      expect(model.located_in(settlement)).to include(record)
      expect(model.located_in(other_settlement)).not_to include(record)
    end

    it 'finds records located at an address that sits within the settlement', :aggregate_failures do
      address = place_inside(settlement)
      BetterTogether::Geography::LocatableLocation.create!(locatable: record, location: address)

      expect(model.located_in(settlement)).to include(record)
      expect(model.located_in(other_settlement)).not_to include(record)
    end

    it 'lists a record once however it is located' do
      record.update!(settlement_identifier: settlement.identifier)

      expect(model.located_in(settlement).where(id: record.id).to_a.size).to eq(1)
    end

    it 'does not find records without a location' do
      expect(model.located_in(settlement)).not_to include(record)
    end
  end
end
