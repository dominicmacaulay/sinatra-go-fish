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
    player_api_key = make_api_key
    player = Player.new(params['name'], player_api_key)
    session[:current_player] = player
    session[:api_key] = player_api_key
    keys << player_api_key
    game.add_player(player)
    respond_to do |f|
      f.html { redirect '/game' }
      f.json { json api_key: player_api_key }
    end
  end

  get '/game' do
    redirect '/' if game.empty?

    respond_to do |f|
      f.html do
        halt 401, "These are not the fish you're looking for..." unless session[:current_player]
        slim :game, locals: { game: game, current_player: session[:current_player] }
      end
      f.json do
        protected!
        json players: game.players
      end
    end
  end

  private

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
