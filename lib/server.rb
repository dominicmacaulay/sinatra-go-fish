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

  get '/' do
    slim :index
  end

  post '/join' do
    player_api_key = make_api_key
    player = Player.new(params['name'], player_api_key)
    session[:current_player] = player
    game.add_player(player)
    respond_to do |f|
      f.html { redirect '/game' }
      f.json { json api_key: player_api_key }
    end
  end

  get '/game' do
    redirect '/' if game.empty?
    respond_to do |f|
      f.html { slim :game, locals: { game: game, current_player: session[:current_player] } }
      f.json { json players: game.players }
    end
  end

  def make_api_key
    SecureRandom.hex(10)
  end
end
