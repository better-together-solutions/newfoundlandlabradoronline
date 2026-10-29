# frozen_string_literal: true

# Kept so every database has the same migration history. The conversion of the earlier election tables into dated
# memberships ran once in production and no longer exists; new installs seed the civic model directly.
class BackfillCivicRoles < ActiveRecord::Migration[8.1]
  def change; end
end
