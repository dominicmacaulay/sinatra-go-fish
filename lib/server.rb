# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'sinatra/respond_with'
require 'rack/contrib'
require 'securerandom'
require 'oj'

require_relative 'go-fish/player'
require_relative 'go-fish/game'

class Server < Sinatra::Base # rubocop:disable Style/Documentation
  enable :sessions
  register Sinatra::RespondWith
  use Rack::JSONBodyParser

  def self.game
    @@game ||= Game.new
  end

  def self.keys
    @@keys ||= []
  end

  def self.reset!
    @@keys = nil
    @@game = nil
  end

  get '/' do
    slim :index
  end

  post '/join' do
    halt 423, 'Sorry. This game is full...' if self.class.game.started
    name = validate_player_name
    player_api_key = make_api_key
    create_player(name, player_api_key)
    respond_to do |f|
      f.html { redirect '/game' }
      f.json { json api_key: player_api_key }
    end
  end

  get '/game' do
    redirect '/' if self.class.game.empty? || !session[:session_player]
    start_game_if_possible

    respond_to do |f|
      f.html do
        slim :game,
             locals: { game: self.class.game, session_player: session[:session_player], api_key: session[:api_key] }
      end
      f.json do
        protected!
        # Oj.dump(self.class.game)
        json self.class.game.as_json
      end
    end
  end

  post '/game' do
    redirect '/game'
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

    halt 401, "These are not the fish you're looking for..."
  end

  def authorized?
    auth ||= Rack::Auth::Basic::Request.new(request.env)
    self.class.game.players.find { |player| player.api_key == auth.username }
  end
end
