# frozen_string_literal: true

# Signs a user in over the CE API and returns request headers carrying the JWT.
module ApiAuthHelpers
  def api_auth_headers(user, password: 'SecureTest123!@#', content_type: 'application/json')
    post '/api/auth/sign-in', params: { user: { email: user.email, password: } }, as: :json
    token = response.headers['Authorization'].to_s.delete_prefix('Bearer ')
    { 'Authorization' => "Bearer #{token}", 'Content-Type' => content_type, 'Accept' => content_type }
  end
end

RSpec.configure { |config| config.include ApiAuthHelpers, type: :request }
