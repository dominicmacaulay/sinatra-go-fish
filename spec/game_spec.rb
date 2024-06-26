# frozen_string_literal: true

require_relative '../lib/go-fish/game'
require_relative '../lib/go-fish/player'
require_relative '../lib/go-fish/round_result'
require_relative 'spec_helper'

RSpec.describe Game do
  let(:player1) { Player.new('Dom', '123') }
  let(:player2) { Player.new('Josh', '456') }
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

  describe 'play_round' do
    before do
      game.add_player(player1)
      game.add_player(player2)
      game.current_player = player1
      player1.add_to_hand(Card.new('4', 'Hearts'))
    end
    describe 'runs transaction when opponent has the card' do
      before do
        player2.add_to_hand(Card.new('4', 'Spades'))
      end
      it 'take the card from the opponent and gives it to the player' do
        game.play_round(player2.api_key, '4')
        expect(player2.hand_has_rank?('4')).to be false
        expect(player1.rank_count('4')).to be 2
      end
      xit 'returns object' do
        result = game.play_round(player2, '4')
        object = RoundResult.new(player: player1, opponent: player2, rank: '4', got_rank: true, amount: 'one')
        expect(result).to eq object
      end
    end

    describe 'runs transaction if the pond has no cards in it' do
      xit 'sends the player a message saying that the pond was empty' do
        game.deck.clear_cards
        result = game.play_round(player2, '4')
        object = RoundResult.new(player: player1, opponent: player2, rank: '4', fished: true, empty_pond: true)
        expect(result).to eq object
      end
    end

    describe 'runs transaction with the pond' do
      xit 'returns message object if the player got the card they wanted' do
        game = Game.new([player1, player2], deck_cards: [Card.new('4', 'Spades')])
        result = game.play_round(player2, '4')
        object = RoundResult.new(player: player1, opponent: player2, rank: '4', fished: true, got_rank: true)
        expect(result).to eq object
      end
      xit 'returns a message object if the player did not get the card they wanted' do
        game = Game.new([player1, player2], deck_cards: [Card.new('4', 'Spades')])
        result = game.play_round(player2, '2')
        object = RoundResult.new(player: player1, opponent: player2, rank: '2', fished: true, card_gotten: '4')
        expect(result).to eq object
      end
    end

    describe 'creating a book' do
      xit 'creates books if possible' do
        player2.add_to_hand([Card.new('4', 'Clubs'), Card.new('4', 'Spades'), Card.new('4', 'Diamonds')])
        game.play_round(player2, '4')
        expect(player1.book_count).to be 1
      end
    end

    describe 'switching the player' do
      xit 'switches the player after the transactions has occurred if they did not get the card they wanted' do
        game = Game.new([player1, player2], deck_cards: [Card.new('6', 'Spades')])
        player2.add_to_hand(Card.new('5', 'Clubs'))
        game.play_round(player2, '4')
        expect(game.current_player).to eql player2
      end

      xit 'does not switch players if the player got what they wanted from the opponent' do
        player1.add_to_hand(Card.new('4', 'Spades'))
        player2.add_to_hand(Card.new('4', 'Clubs'))
        game.play_round(player2, '4')
        expect(game.current_player).to eql player1
      end

      xit 'does not switch players if the player got what they wanted from the pond' do
        game = Game.new([player1, player2], deck_cards: [Card.new('4', 'Diamonds')])
        player1.add_to_hand(Card.new('4', 'Spades'))
        player2.add_to_hand(Card.new('5', 'Clubs'))
        game.play_round(player2, '4')
        expect(game.current_player).to eql player1
      end
    end
  end
end
