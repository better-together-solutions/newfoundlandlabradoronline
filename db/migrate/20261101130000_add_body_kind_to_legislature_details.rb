# frozen_string_literal: true

# Says what sort of body a legislature community is: a legislature, a municipal council or a local service district
# committee (elected, advisory, no council powers).
class AddBodyKindToLegislatureDetails < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:legislature_details, :body_kind)

    add_column :legislature_details, :body_kind, :string, limit: 30, default: 'legislature', null: false
  end
end
