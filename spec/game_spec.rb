# frozen_string_literal: true

require_relative '../lib/go-fish/game'
require_relative '../lib/go-fish/player'
require_relative '../lib/go-fish/round_result'
require_relative 'spec_helper'

RSpec.describe Game do
  let(:player1) { Player.new('Dom', 1) }
  let(:player2) { Player.new('Josh', 1) }
  let(:game) { Game.new }
  describe 'initialization' do
    it 'creates variables with correct values' do
      expect(game.deck).to respond_to(:cards)
      expect(game.started).to be false
    end
  end

  describe 'add_players' do
    it 'adds the given player to the players array' do
      game.add_player(player1)
      expect(game.players).to include(player1)
      game.add_player(player2)
      expect(game.players).to include(player1, player2)
    end
  end

  describe 'start' do
    before do
      game.add_player(player1)
      game.add_player(player2)
    end
    it 'shuffles the deck' do
      expect(game.deck).to receive(:shuffle).once
      game.start
    end
    it 'deals each player the standard amount of cards' do
      expect(player1.hand).to be_empty
      expect(player2.hand).to be_empty
      game.start
      expect(player1.hand.count).to eql game.deal_number
      expect(player2.hand.count).to eql game.deal_number
    end
  end
end
