# frozen_string_literal: true

require 'rack/test'
require 'rspec'
require 'json'
require 'capybara'
require 'capybara/dsl'
ENV['RACK_ENV'] = 'test'
require_relative '../lib/server'
require_relative '../lib/go-fish/card'

RSpec.describe Server do
  include Capybara::DSL

  before do
    Capybara.app = Server.new
  end
  after do
    Server.reset!
  end

  describe 'onboarding the player' do
    it 'is possible to join a game' do
      api_index('John')
      expect(page).to have_content('Players')
      expect(page).to have_content('John')
    end

    it 'redirects the player to enter their name again if the name is invalid' do
      visit '/'
      click_on 'Join'
      expect(page).to have_content('Enter your name')
    end

    it 'redirects to index if the client is not a player' do
      visit '/game'
      expect(page).to have_content('Enter your name')
    end

    it "doesn't display cards or a current player when there aren't enough players" do
      api_index('John')
      expect(page).not_to have_content('Hand')
      expect(page).not_to have_content('Books')
      expect(page).not_to have_content('current player')
      expect(page).not_to have_content('Ask Player')
    end

    it "doesn't start the game if there are not enough players" do
      api_index('John')
      expect(Server.game.started).not_to be true
    end
  end

  describe 'show generic information' do
    before do
      @session1 = create_session_and_player('Player 1')
      @session2 = create_session_and_player('Player 2')
      [@session1, @session2].each { |session| session.driver.refresh }
    end

    it 'displays cards, books and the current player when there are enough players' do
      [@session1, @session2].each do |session|
        expect(session).to have_content('Hand', count: 1)
        expect(session).to have_content('Books: none', count: 2)
        expect(session).to have_content('current player', count: 1)
      end
    end

    it 'allows multiple players to join game' do
      [@session1, @session2].each_with_index do |session, index|
        player_name = "Player #{index + 1}"
        expect(session).to have_content('Players')
        expect(session).to have_css('strong', text: player_name)
      end
      expect(@session2).to have_content('Player 1')
      expect(@session1).to have_content('Player 2')
    end

    it 'does not show opponents in bold and reveals the personal api only' do
      expect(@session2).not_to have_css('strong', text: 'Player 1')
      expect(@session2).to have_content('api key', count: 1)
      expect(@session1).not_to have_css('strong', text: 'Player 2')
      expect(@session2).to have_content('api key', count: 1)
    end
  end

  describe 'show subjective hand and card information' do
    before do
      @session1 = create_session_and_player('Player 1')
      @session2 = create_session_and_player('Player 2')
      Server.game.players.each { |player| player.hand.clear }
      Server.game.players.first.add_to_hand(create_cards('4', 4))
      Server.game.players.last.add_to_hand(create_cards('2', 4))
      [@session1, @session2].each { |session| session.driver.refresh }
    end

    it 'displays the session player hand only' do
      expect(@session1).to have_content('4 of Hearts')
      expect(@session2).to have_content('2 of Spades')
      expect(@session1).not_to have_content('2 of Spades')
      expect(@session2).not_to have_content('4 of Hearts')
    end

    it 'displays the session player hand only' do
      Server.game.players.each(&:make_book?)
      [@session1, @session2].each { |session| session.driver.refresh }
      expect(@session1).not_to have_content('Books: none')
      expect(@session2).not_to have_content('Books: none')
      expect(@session1).to have_content("4's")
      expect(@session2).to have_content("2's")
    end

    it "displays the turn actions to the game's current player" do
      expect(@session1).to have_content('Ask Player')
      expect(@session2).not_to have_content('Ask Player')
    end
  end

  describe 'plays a turn' do
    before do
      @player1_name = 'Player 1'
      @player2_name = 'Player 2'
      @session1 = create_session_and_player(@player1_name)
      @session2 = create_session_and_player(@player2_name)
      Server.game.players.each { |player| player.hand.clear }
      Server.game.players.first.add_to_hand([*create_cards('6', 1), *create_cards('8', 2)])
      Server.game.players.last.add_to_hand([*create_cards('2', 1), *create_cards('8', 1)])
      [@session1, @session2].each { |session| session.driver.refresh }
    end

    it 'allows the current player to select an opponent' do
      expect(@session1).to have_select('opponent', with_options: [@player2_name])
      expect(@session1).not_to have_select('opponent', with_options: [@player1_name])
      expect(@session2).not_to have_select('opponent')
    end

    it 'allows the current player to select a rank' do
      expect(@session1).to have_select('card_rank', with_options: %w[6 8])
      expect(@session1).to have_select('card_rank', with_options: %w[8], count: 1)
      expect(@session1).not_to have_select('card_rank', with_options: %w[2])
      expect(@session2).not_to have_select('card_rank')
    end

    it 'allows the current player to submit their game actions and displays their updated cards' do
      @session1.click_on 'Ask Player'
      expect(@session1).not_to have_content('Ask Player')
      expect(@session1).to have_content('of', count: 4)
    end

    it 'allows the current player to submit their game actions and displays both players updated cards' do
      @session1.select '8', from: 'card_rank'
      @session1.click_on 'Ask Player'
      expect(@session1).to have_content('Ask Player')
      expect(@session1).to have_content('8 of', count: 3)
      @session2.driver.refresh
      expect(@session2).not_to have_content('8 of')
    end

    it 'allows the current player to submit their game actions and displays their updated hand and books' do
      Server.game.players.first.add_to_hand(create_cards('8', 1))
      @session1.select '8', from: 'card_rank'
      @session1.click_on 'Ask Player'
      expect(@session1).to have_content('Ask Player')
      expect(@session1).not_to have_content('8 of')
      expect(@session1).to have_content("8's", count: 2)
    end
  end
end

RSpec.describe Server do
  include Rack::Test::Methods
  def app
    Server.new
  end
  after do
    Server.reset!
  end
  describe 'validates api key' do
    before do
      api_post_join_then_get('John')
    end

    it 'returns game status via API' do
      api_post_join_then_get('Caleb')
      expect(last_response.status).to eq 200
      expect(last_response).to match_json_schema('game')
    end

    it 'returns an error if the key is not authorized' do
      api_post_join('Caleb')
      api_key = '12345'
      api_get_game(api_key)
      expect(last_response.status).to eql 401
    end
  end

  describe 'gets game' do
    before do
      @player1_api_key = api_post_join_then_get('John')
    end

    it 'returns subjective game information for player 2' do
      key = api_post_join_then_get('Caleb')
      expect(response['my_turn']).to be false
      player = player_with_key(key)
      expect(response['my_hand'].to_json).to match player.hand.map(&:as_json).to_json
      expect(response['opponents'].to_json).not_to match player.name.to_s
    end

    it 'returns subjective game information for player 1' do
      api_post_join_then_get('Caleb')
      api_get_game(@player1_api_key)
      expect(response['my_turn']).to be true
      player = player_with_key(@player1_api_key)
      expect(response['my_hand'].to_json).to match player.hand.map(&:as_json).to_json
      expect(response['opponents'].to_json).not_to match player.name.to_s
    end
  end

  describe 'posts game' do
    before do
      @player1_api_key = api_post_join_then_get('John')
      @player1 = player_with_key(@player1_api_key)
      @player2_api_key = api_post_join_then_get('Caleb')
      @player2 = player_with_key(@player2_api_key)
    end
    after do
      Server.reset!
    end

    it 'returns the round result and game json for player 1' do
      rank = @player1.hand.sample.rank
      player2_index = player_index(@player2)
      api_post_game(@player1_api_key, player2_index, rank)
      expect(response['round_result']).to match_json_schema('round_result')
      expect(response['game']).to match_json_schema('game')
    end

    it 'returns accurate data for player 1' do
      rank = @player1.hand.sample.rank
      player2_index = player_index(@player2)
      api_post_game(@player1_api_key, player2_index, rank)
      expect(response['game']['my_hand'].to_json).to match @player1.hand.map(&:as_json).to_json
      expect(response['game']['my_hand'].to_json).to match rank
      expect(response['game']['opponents'].to_json).not_to match @player1.name.to_s
      expect(response['game']['opponents'].to_json).to match @player2.name.to_s
    end
  end
end

def player_index(player)
  Server.game.players.index(player)
end

def player_with_key(key)
  Server.game.players.detect { |player| player.api_key == key }
end

def response
  JSON.parse(last_response.body)
end

def api_get_game(api_key)
  get '/game', nil, {
    'HTTP_AUTHORIZATION' => "Basic #{Base64.encode64("#{api_key}:X")}",
    'HTTP_ACCEPT' => 'application/json'
  }
end

def api_post_join(name)
  post '/join', { 'name' => name.to_s }.to_json, {
    'HTTP_ACCEPT' => 'application/json',
    'CONTENT_TYPE' => 'application/json'
  }
  response['api_key']
end

def api_post_join_then_get(name)
  key = api_post_join(name)
  api_get_game(key)
  key
end

def api_post_game(player1, opponent, rank)
  post '/game', { 'opponent' => opponent, 'card_rank' => rank }.to_json, {
    'HTTP_AUTHORIZATION' => "Basic #{Base64.encode64("#{player1}:X")}",
    'HTTP_ACCEPT' => 'application/json',
    'CONTENT_TYPE' => 'application/json'
  }
end

def api_index(name, session = Capybara)
  session.visit '/'
  session.fill_in :name, with: name
  session.click_on 'Join'
end

def create_session_and_player(name)
  session = Capybara::Session.new(:rack_test, Server.new)
  player_name = name.to_s
  api_index(player_name, session)
  session
end

def create_cards(rank, amount)
  cards = []
  cards.push(Card.new(rank, 'Hearts')) if amount > 0
  cards.push(Card.new(rank, 'Spades')) if amount > 1
  cards.push(Card.new(rank, 'Diamonds')) if amount > 2
  cards.push(Card.new(rank, 'Clubs')) if amount > 3
  cards
end
