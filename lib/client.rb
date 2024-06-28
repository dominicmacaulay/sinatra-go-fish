# frozen_string_literal: true

require 'httparty'
require 'json'
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

  def game_state
    @game_state ||= get_game_response['game']
  end

  def state_changed?
    new_response = get_game_response['game']
    return false if new_response == game_state

    reassign_game_state(new_response)
    true
  end

  def current_turn?
    game_state['my_turn']
  end

  def turn_prompt
    [
      "Oyo boyo. It's your turn!",
      "Enter your opponent's name and the card you'd like to ask from them",
      'Something like this: Motörhead-Ace of Spades'
    ]
  end

  def send_turn(input)
  end

  private

  def reassign_game_state(new_state)
    @game_state = new_state
  end

  def get_game_response # rubocop:disable Naming/AccessorMethodName
    self.class.get('/game', {
                     headers: { 'Http-Authorization' => "Basic #{Base64.encode64("#{api_key}:X")}",
                                'Accept' => 'application/json' }
                   })
  end
end
