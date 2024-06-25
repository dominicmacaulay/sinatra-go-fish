# frozen_string_literal: true

require 'rack/test'
require 'rspec'
require 'capybara'
require 'capybara/dsl'
ENV['RACK_ENV'] = 'test'
require_relative '../lib/server'
RSpec.describe Server do # rubocop:disable Metrics/BlockLength
  include Capybara::DSL

  before do
    Capybara.app = Server.new
  end

  it 'is possible to join a game' do
    api_index('John')
    expect(page).to have_content('Players')
    expect(page).to have_content('John')
  end

  it 'redirects to index if the client is not a player' do
    visit '/game'
    expect(page).to have_content('Enter your name')
  end

  it 'allows multiple players to join game' do
    session1 = Capybara::Session.new(:rack_test, Server.new)
    session2 = Capybara::Session.new(:rack_test, Server.new)
    [session1, session2].each_with_index do |session, index|
      player_name = "Player #{index + 1}"
      api_index(player_name, session)
      expect(session).to have_content('Players')
      expect(session).to have_css('b', text: player_name)
    end
    expect(session2).to have_content('Player 1')
    session1.driver.refresh
    expect(session1).to have_content('Player 2')
  end

  it 'does not show opponents in bold and reveals the personal api only' do
    session1 = Capybara::Session.new(:rack_test, Server.new)
    session2 = Capybara::Session.new(:rack_test, Server.new)
    [session1, session2].each_with_index do |session, index|
      player_name = "Player #{index + 1}"
      api_index(player_name, session)
    end
    expect(session2).to have_content('Player 1')
    expect(session2).not_to have_css('b', text: 'Player 1')
    expect(session2).to have_content('api key', count: 1)
    session1.driver.refresh
    expect(session1).to have_content('Player 2')
    expect(session1).not_to have_css('b', text: 'Player 2')
    expect(session2).to have_content('api key', count: 1)
  end
end

RSpec.describe Server do
  include Rack::Test::Methods
  def app
    Server.new
  end
  #   after do
  #     Server.reset!
  #   end
  it 'returns game status via API' do
    api_post('Caleb')
    api_key = JSON.parse(last_response.body)['api_key']
    expect(api_key).not_to be_nil
    api_get(api_key)
    expect(JSON.parse(last_response.body).keys).to include 'players'
  end

  it 'returns an error if the key is not authorized' do
    api_post('Caleb')
    api_key = '12345'
    api_get(api_key)
    expect(last_response.status).to eql 401
  end
end

def api_get(api_key)
  get '/game', nil, {
    'HTTP_AUTHORIZATION' => "Basic #{Base64.encode64("#{api_key}:X")}",
    'HTTP_ACCEPT' => 'application/json'
  }
end

def api_post(name)
  post '/join', { 'name' => name.to_s }.to_json, {
    'HTTP_ACCEPT' => 'application/json',
    'CONTENT_TYPE' => 'application/json'
  }
end

def api_index(name, session = nil)
  if session
    session.visit '/'
    session.fill_in :name, with: name
    session.click_on 'Join'
  else
    visit '/'
    fill_in :name, with: name.to_s
    click_on 'Join'
  end
end
