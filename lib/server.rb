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
      f.html do
        session['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64("#{player_api_key}:X")}"
        redirect '/game'
      end
      f.json { json api_key: player_api_key }
    end
  end

  get '/game' do
    redirect '/' if game.empty?
    # TODO: if the passed in params contain an api key that is recognized, continue else send 401
    key = session['HTTP_AUTHORIZATION'].nil? ? request.env['HTTP_AUTHORIZATION'] : session['HTTP_AUTHORIZATION']
    halt 401, 'Unauthorized' unless valid_api_key?(key)

    respond_to do |f|
      f.html { slim :game, locals: { game: game, current_player: session[:current_player] } }
      f.json { json players: game.players }
    end
  end

  private

  def make_api_key
    SecureRandom.hex(10)
  end

  def valid_api_key?(key)
    credentials = key.split(' ').last
    api_key = Base64.decode64(credentials).split(':').first
    game.players.each do |player|
      return true if api_key.include? player.api_key
    end
    false
  end
end
