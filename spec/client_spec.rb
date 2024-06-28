# frozen_string_literal: true

# client_spec.rb

require 'spec_helper'
require_relative '../lib/client'
require_relative '../lib/go-fish/game'
require_relative '../lib/go-fish/player'

RSpec.describe Client do
  describe '#join_game' do
    it 'connects to server and stores API key' do
      test_api_key = 'random_string'
      stub_request(:post, %r{/join}).to_return_json(body: { api_key: test_api_key })

      client = Client.new(player_name: 'Test')
      client.join_game
      expect(client.api_key).to eq test_api_key
    end
  end

  describe 'game_state' do
    it 'shows the game state' do
      test_game = Game.new
      stub_request(:post, %r{/join}).to_return_json(body: { api_key: 'random_string' })
      stub_request(:get, %r{/game}).to_return_json(body: { game: test_game })

      client = Client.new(player_name: 'Test')
      client.join_game
      expect(client.game_state).to eq test_game.to_s
    end
  end

  describe 'state_changed?' do
    before do
      @test_game = Game.new
      stub_request(:post, %r{/join}).to_return_json(body: { api_key: 'random_string' })
      stub_request(:get, %r{/game}).to_return_json(body: { game: @test_game })

      @client = Client.new(player_name: 'Test')
      @client.join_game
      @client.game_state
    end
    it 'indicates that the game state has not changed' do
      stub_request(:get, %r{/game}).to_return_json(body: { game: @test_game })
      expect(@client.state_changed?).to be false
    end

    it 'indicates that the game state has changed and updates the game_state' do
      new_game = Game.new
      stub_request(:get, %r{/game}).to_return_json(body: { game: new_game })
      expect(@client.state_changed?).to be true
      expect(@client.game_state).to eql new_game.to_s
    end
  end

  describe 'current_turn?' do
    before do
      @player = Player.new('Test', 'random_string')
      @test_game = Game.new([@player])
      @test_game.current_player = @player
      stub_request(:post, %r{/join}).to_return_json(body: { api_key: 'random_string' })
      stub_request(:get, %r{/game}).to_return_json(body: { game: @test_game.as_json(@player) })

      @client = Client.new(player_name: 'Test')
      @client.join_game
      @client.game_state
    end
    it "indicates that it is the player's turn" do
      expect(@client.current_turn?).to be true
    end
    it "indicates that it is not the player's turn" do
      opponent = Player.new('Opponent', 'random_string_2')
      @test_game.current_player = opponent

      stub_request(:get, %r{/game}).to_return_json(body: { game: @test_game.as_json(@player) })
      @client.state_changed?

      expect(@client.current_turn?).to be false
    end
  end

  describe 'turn_prompt' do
    it 'prompts the player' do
      client = Client.new(player_name: 'Test')
      expect(client.turn_prompt).to include(include 'Enter')
    end
  end

  describe 'send_turn' do
    it 'takes a string and extracts the name and rank' do
      client = Client.new(player_name: 'Test')
      extracted_values = client.send_turn('Jamison for Jack of Hearts')
      expect(extracted_values.first).to eql 'Jamison'
      expect(extracted_values.last).to eql 'Jack'
    end
    it 'returns false if the input is improperly formatted' do
      client = Client.new(player_name: 'Test')
      extracted_values = client.send_turn('Jamison  Jack of Hearts')
      expect(extracted_values).to be nil
    end
  end
end
