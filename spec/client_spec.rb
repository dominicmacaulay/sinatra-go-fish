# frozen_string_literal: true

# client_spec.rb

require 'spec_helper'
require_relative '../lib/client'

RSpec.describe Client do
  describe '#join_game' do
    it 'connects to server and stores API key' do
      test_api_key = 'random_string'
      stub_request(:post, %r{/join}).to_return_json(body: { api_key: test_api_key })

      client = Client.new(player_name: 'Test')
      client.join_game
      expect(client.api_key).to eq test_api_key
    end
  end
end
