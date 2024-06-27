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
      expect(game.winners).to be nil
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
      it 'returns object' do
        result = game.play_round(player2.api_key, '4')
        object = RoundResult.new(player: player1, opponent: player2, rank: '4', got_rank: true, amount: 'one')
        expect(result).to eq object
      end
    end

    describe 'runs transaction if the pond has no cards in it' do
      it 'sends the player a message saying that the pond was empty' do
        game.deck.clear_cards
        result = game.play_round(player2.api_key, '4')
        object = RoundResult.new(player: player1, opponent: player2, rank: '4', fished: true, empty_pond: true)
        expect(result).to eq object
      end
    end

    describe 'runs transaction with the pond' do
      it 'returns message object if the player got the card they wanted' do
        game = Game.new([player1, player2], deck_cards: [Card.new('4', 'Spades')])
        game.current_player = player1
        result = game.play_round(player2.api_key, '4')
        object = RoundResult.new(player: player1, opponent: player2, rank: '4', fished: true, got_rank: true)
        expect(result).to eq object
      end
      it 'returns a message object if the player did not get the card they wanted' do
        game = Game.new([player1, player2], deck_cards: [Card.new('4', 'Spades')])
        game.current_player = player1
        result = game.play_round(player2.api_key, '2')
        object = RoundResult.new(player: player1, opponent: player2, rank: '2', fished: true, card_gotten: '4')
        expect(result).to eq object
      end
    end

    describe 'creating a book' do
      it 'creates books if possible' do
        player2.add_to_hand([Card.new('4', 'Clubs'), Card.new('4', 'Spades'), Card.new('4', 'Diamonds')])
        game.play_round(player2.api_key, '4')
        expect(player1.book_count).to be 1
      end
    end

    describe 'switching the player' do
      it 'switches the player after the transactions has occurred if they did not get the card they wanted' do
        game = Game.new([player1, player2], deck_cards: [Card.new('6', 'Spades')])
        game.current_player = player1
        player2.add_to_hand(Card.new('5', 'Clubs'))
        game.play_round(player2.api_key, '4')
        expect(game.current_player).to eql player2
      end

      it 'does not switch players if the player got what they wanted from the opponent' do
        player1.add_to_hand(Card.new('4', 'Spades'))
        player2.add_to_hand(Card.new('4', 'Clubs'))
        game.play_round(player2.api_key, '4')
        expect(game.current_player).to eql player1
      end

      it 'does not switch players if the player got what they wanted from the pond' do
        game = Game.new([player1, player2], deck_cards: [Card.new('4', 'Diamonds')])
        game.current_player = player1
        player1.add_to_hand(Card.new('4', 'Spades'))
        player2.add_to_hand(Card.new('5', 'Clubs'))
        game.play_round(player2.api_key, '4')
        expect(game.current_player).to eql player1
      end
    end

    describe 'checks for winner' do
      let(:books) { make_books(13) }
      it 'declares the winner with the most books' do
        winner = Player.new('Winner', 123, books: books.shift(7))
        loser = Player.new('Loser', 456, books: books.shift(6))
        winner_game = Game.new([winner, loser], deck_cards: [0])
        winner_game.deck.deal
        winner_game.check_for_winners
        expect(winner_game.display_winners).to eql 'Winner won the game with 7 books totalling in 28'
      end
      it 'in case of a book tie, declares the winner with the highest book value' do
        winner = Player.new('Winner', 123, books: books.pop(6))
        loser1 = Player.new('Loser', 456, books: books.shift(6))
        loser2 = Player.new('Loser', 789, books: books.shift(1))
        winner_game = Game.new([winner, loser1, loser2], deck_cards: [0])
        winner_game.deck.deal
        winner_game.check_for_winners
        expect(winner_game.display_winners).to eql 'Winner won the game with 6 books totalling in 63'
      end
      it 'in case of total tie, display tie messge' do
        winner = Player.new('Winner1', 123, books: [books[1], books[3], books[5], books[7], books[9], books[11]])
        loser1 = Player.new('Winner2', 456, books: [books[0], books[2], books[4], books[8], books[10], books[12]])
        loser2 = Player.new('Loser', 789, books: [books[6]])
        winner_game = Game.new([winner, loser1, loser2], deck_cards: [0])
        winner_game.deck.deal
        winner_game.check_for_winners
        expect(winner_game.display_winners).to eql 'Winner1 and Winner2 tied with 6 books totalling in 42'
      end
    end
  end

  describe 'smoke test' do
    let(:player1) { Player.new('Dom', 123) }
    let(:player2) { Player.new('Micah', 456) }
    let(:player3) { Player.new('Josh', 789) }
    let(:game) { Game.new([player1, player2, player3]) }
    it 'runs test' do
      game.start
      until game.winners
        game.deal_to_player_if_necessary
        current_index = game.players.index(game.current_player)
        other_player = game.players[(current_index + 1) % game.players.count]
        rank = game.current_player.hand.sample.rank
        puts "#{game.current_player.name} is asking for #{rank}'s"
        message = game.play_round(other_player, rank)
        puts message.display_for(game.players[current_index])
        puts message.display_for(other_player)
        puts message.display_for(game.players[(current_index + 2) % game.players.count])
        puts
      end
      puts game.display_winners
    end
  end
end

def make_books(times)
  deck = retrieve_one_deck
  books = []
  times.times do
    books.push(Book.new(deck.shift))
  end
  books
end

def retrieve_one_deck
  Card::RANKS.map do |rank|
    Card::SUITS.flat_map do |suit|
      Card.new(rank, suit)
    end
  end
end
