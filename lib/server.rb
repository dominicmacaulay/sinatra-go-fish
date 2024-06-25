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

  def game
    @@game ||= Game.new
  end

  def keys
    @keys ||= []
  end

  #   def reset
  #     @keys = []
  #     @@game = Game.new
  #   end

  get '/' do
    slim :index
  end

  post '/join' do
    name = validate_player_name
    player_api_key = make_api_key
    create_player(name, player_api_key)
    respond_to do |f|
      f.html { redirect '/game' }
      f.json { json api_key: player_api_key }
    end
  end

  get '/game' do
    redirect '/' if game.empty? || !session[:current_player]

    respond_to do |f|
      f.html do
        slim :game, locals: { game: game, current_player: session[:current_player] }
      end
      f.json do
        protected!
        json players: game.players
      end
    end
  end

  private

  def validate_player_name
    name = params['name']
    redirect '/' unless name.length.positive?
    name
  end

  def create_player(name, api_key)
    player = Player.new(name, api_key)
    session[:current_player] = player
    session[:api_key] = api_key
    keys << api_key
    game.add_player(player)
  end

  def make_api_key
    SecureRandom.hex(10)
  end

  def protected!
    return if authorized?

    halt 401, 'Not authorized...'
  end

  def authorized?
    auth ||= Rack::Auth::Basic::Request.new(request.env)
    game.players.find { |player| player.api_key == auth.credentials.first }
  end
end
