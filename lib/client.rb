# frozen_string_literal: true

require 'httparty'
require 'json'
require 'base64'

# client.rb
class Client
  include HTTParty

  attr_reader :player_name, :api_key
  attr_accessor :trying_again, :post_game_response

  def initialize(player_name:, url: 'http://localhost:9292')
    self.class.base_uri url
    @player_name = player_name
    @trying_again = false
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
    parse_info(game_state_json)
  end

  def game_state_json
    @game_state_json ||= get_game_response
  end

  def state_changed?
    new_response = get_game_response
    new_response.each_key do |key|
      return false if new_response[key] == game_state_json[key]
    end

    reassign_game_state(new_response)
    true
  end

  def current_turn?
    return false if game_state_json['game'].nil?

    game_state_json['game']['my_turn']
  end

  def turn_prompt
    return initial_prompt unless trying_again

    self.trying_again = false
    retry_prompt
  end

  def send_turn(input)
    return false unless input.include?('for')

    name, rank = retrieve_name_and_rank(input)
    post_to_game(name, rank)
    [name, rank]
  end

  private

  def initial_prompt
    [
      "Oyo boyo. It's your turn!",
      "Enter your opponent's name and the card you'd like to ask from them",
      'Remember, you can only select an opponent and one of your own cards',
      'Something like this: Motörhead for Ace of Spades',
      "make sure you include that 'for' in between them it won't work otherwise."
    ]
  end

  def retry_prompt
    [
      'Hey now boyo. You need to follow instructions.',
      'Remember, you can only select an opponent and one of your own cards',
      'Try again...'
    ]
  end

  def post_to_game(opponent, rank)
    self.class.post('/game', {
                      body: { 'opponent' => opponent, 'card_rank' => rank }.to_json,
                      headers: { 'Authorization' => "Basic #{Base64.encode64("#{api_key}:X")}",
                                 'Accept' => 'application/json',
                                 'Content-Type' => 'application/json' }
                    })
  end

  def retrieve_name_and_rank(string)
    selections = string.split('for')
    name = selections.first.strip
    card = selections.last.split(' ')
    rank = card.first.strip
    [name, rank]
  end

  def reassign_game_state(new_state)
    @game_state_json = new_state
  end

  def get_game_response # rubocop:disable Naming/AccessorMethodName
    self.class.get('/game', {
                     headers: { 'Authorization' => "Basic #{Base64.encode64("#{api_key}:X")}",
                                'Accept' => 'application/json' }
                   })
  end

  def parse_info(json)
    return json['pending'] if json['pending']

    message = [
      '',
      "Your hand: #{display_cards(json['game'])}",
      "Your books: #{display_books(json['game'])}",
      "Your opponents: #{display_opponents(json['game'])}"
    ]
    message.push(json['round_result'].to_s) if json['round_result']
    message
  end

  def display_cards(json)
    json['my_hand'].map do |card|
      "#{card['rank']} of #{card['suit']}, "
    end
  end

  def display_books(json)
    json['books'].map do |card|
      (card['rank']).to_s
    end
  end

  def display_opponents(json)
    json['opponents'].map do |opponent|
      "#{opponent['name']}, Books: #{display_books(opponent)}"
    end
  end
end
