# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::NamespacedPageSlug do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }

  def page_with_slug(slug)
    BetterTogether::Page.new(title: 'EXPLORA III', slug:, platform:, privacy: 'private')
  end

  it 'prepends the page model' do
    expect(BetterTogether::Page.ancestors.first(2)).to include(described_class)
  end

  it 'keeps the forward slash in a namespaced slug', :aggregate_failures do
    page = page_with_slug('ships/mt-explora-iii')

    expect(page).to be_valid
    expect(page.slug).to eq('ships/mt-explora-iii')
  end

  it 'parameterizes each segment on its own' do
    page = page_with_slug('Ships/MT Explora III')
    page.valid?

    expect(page.slug).to eq('ships/mt-explora-iii')
  end

  it 'leaves an ordinary slug unchanged' do
    page = page_with_slug('about-us')
    page.valid?

    expect(page.slug).to eq('about-us')
  end

  it 'still derives a slug from the title when none is given' do
    page = BetterTogether::Page.new(title: 'Corner Brook Weather', platform:, privacy: 'private')
    page.valid?

    expect(page.slug).to eq('corner-brook-weather')
  end
end
