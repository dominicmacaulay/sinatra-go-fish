# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'sinatra/respond_with'
require 'rack/contrib'
require 'securerandom'

require_relative 'go-fish/player'
require_relative 'go-fish/game'

class Server < Sinatra::Base # rubocop:disable Style/Documentation
  enable :sessions
  register Sinatra::RespondWith
  use Rack::JSONBodyParser

  def self.game
    @@game ||= Game.new # rubocop:disable Style/ClassVars
  end

  def self.keys
    @@keys ||= [] # rubocop:disable Style/ClassVars
  end

  def self.round_result
    @@round_result ||= nil # rubocop:disable Style/ClassVars
  end

  def self.reset!
    @@keys = nil # rubocop:disable Style/ClassVars
    @@game = nil # rubocop:disable Style/ClassVars
    @@round_result = nil # rubocop:disable Style/ClassVars
  end

  get '/' do
    slim :index
  end

  post '/join' do
    halt 423, json(error: 'Sorry. This game is full...') if self.class.game.started
    name = validate_player_name
    player_api_key = make_api_key
    create_player(name, player_api_key)
    start_game_if_possible

    respond_to do |f|
      f.html { redirect '/game' }
      f.json { json api_key: player_api_key }
    end
  end

  get '/game' do
    redirect '/' if self.class.game.empty? || !session[:session_player]

    if self.class.game.winners
      game_over_message = self.class.game.display_winners
      initial_message = nil
    else
      initial_message = (self.class.game.current_player == session[:session_player] ? self.class.game.deal_to_player_if_necessary : nil) # rubocop:disable Layout/LineLength
      game_over_message = nil
    end
    respond_to do |f|
      f.html do
        slim :game,
             locals: { game: self.class.game, session_player: session[:session_player], api_key: session[:api_key],
                       round_result: self.class.round_result, initial_message: initial_message, game_over_message: game_over_message } # rubocop:disable Layout/LineLength
      end
      f.json do
        protected!
        json self.class.game.as_json(session[:session_player])
      end
    end
  end

  post '/game' do
    # TODO: validate the inputs first
    respond_to do |f|
      f.html do
        @@round_result = self.class.game.play_round(params['opponent'], params['card_rank']) # rubocop:disable Style/ClassVars
        redirect '/game'
      end
      f.json do
        protected!
        halt 401, json(error: "Ain't your turn boyo") unless session[:session_player] == self.class.game.current_player
        @@round_result = self.class.game.play_round(params['opponent'], params['card_rank']) # rubocop:disable Style/ClassVars
        json round_result: self.class.round_result.as_json, game: self.class.game.as_json(session[:session_player])
      end
    end
  end

  private

  def start_game_if_possible
    return if self.class.game.started == true

    self.class.game.start if self.class.game.players.count == Game::PLAYER_CAPACITY
  end

  def validate_player_name
    name = params['name']
    redirect '/' unless name.length.positive?
    name
  end

  def create_player(name, api_key)
    player = Player.new(name, api_key)
    session[:session_player] = player
    session[:api_key] = api_key
    self.class.keys << api_key
    self.class.game.add_player(player)
  end

  def make_api_key
    SecureRandom.hex(10)
  end

  def protected!
    return if authorized?

    halt 401, json(error: "These are not the fish you're looking for...")
  end

  def authorized? # rubocop:disable Metrics/AbcSize
    auth ||= Rack::Auth::Basic::Request.new(request.env)
    player_with_key = self.class.game.players.detect { |player| player.api_key == auth.username }
    unless player_with_key.nil?
      session[:session_player] = player_with_key
      session[:api_key] = auth.username
    end
    !player_with_key.nil?
  end
end
