# frozen_string_literal: true

require 'httparty'
# client.rb
class Client
  include HTTParty

  attr_reader :player_name, :api_key

  def initialize(player_name:, url: 'http://localhost:9292')
    self.class.base_uri url
    @player_name = player_name
  end

  def join_game
    response = self.class.post('/join', {
                                 body: { name: player_name }.to_json,
                                 headers: { 'Content-Type' => 'application/json',
                                            'Accept' => 'application/json' }
                               })
    @api_key = response['api_key']
  end
end
