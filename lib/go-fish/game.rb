# frozen_string_literal: false

require_relative 'deck'
require_relative 'round_result'

# go fish game class
class Game
  PLAYER_CAPACITY = 2
  MINIMUM_BOOK_LENGTH = 4
  attr_reader :players, :deal_number, :deck_cards
  attr_accessor :current_player, :started, :winners

  def initialize(players = [], deal_number: 5, deck_cards: nil)
    @players = players
    @deal_number = deal_number
    @deck_cards = deck_cards
    @current_player = nil
    @started = false
    @winners = nil
  end

  def empty?
    players.empty?
  end

  def add_player(player)
    players << player
  end

  def deck
    @deck ||= deck_cards.nil? ? Deck.new : Deck.new(cards: deck_cards)
  end

  def start
    deck.shuffle
    deal_number.times do
      players.each { |player| player.add_to_hand(deck.deal) }
    end
    self.current_player = players.first
    self.started = true
  end

  # TODO: place validation methods

  def deal_to_player_if_necessary
    return if current_player.hand_count.positive?

    if deck.cards_count.zero?
      switch_player
      return 'Sorry. Your hand is empty and there are no cards in the pond. You will have to sit this one out.'
    end

    current_player.add_to_hand(deck.deal)
    'Your hand was empty, but you received a card from the pond!'
  end

  def play_round(opponent_id, rank)
    message = run_transaction(opponent_id, rank)
    message.book_was_made if current_player.make_book?
    switch_player unless message.got_rank
    check_for_winners
    message
  end

  def check_for_winners
    return unless deck.cards_count.zero? && players.map(&:hand_count).sum.zero?

    self.winners = determine_winners
  end

  def display_winners # rubocop:disable Metrics/AbcSize
    if winners.count > 1
      message = display_winner_names
      message.concat(" tied with #{winners.first.book_count} books totalling in #{winners.first.total_book_value}")
      return message
    end

    "#{winners.first.name} won the game with #{winners.first.book_count} books totalling in #{winners.first.total_book_value}" # rubocop:disable Layout/LineLength
  end

  def as_json(session_player)
    json = { players: players.map { |player| player.as_json(session_player == player) },
             deck: deck.as_json,
             deal_number: deal_number,
             started: started }
    json[current_player] = current_player.as_json if current_player == session_player
    json
  end

  private

  def display_winner_names # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    message = ''
    winners.each do |winner|
      message.concat('and ') if winner == winners.last && winner != winners.first
      message.concat(winner == winners.first && winners.length == 2 ? "#{winner.name} " : winner.name.to_s)
      message.concat(', ') unless winner == winners.last || winners.length == 2
    end
    message
  end

  def determine_winners
    max_books = players.map(&:book_count).max
    players_with_max_books = players.select { |player| player.book_count == max_books }
    return players_with_max_books unless players_with_max_books.count > 1

    max_book_value = players.map(&:total_book_value).max
    players.select { |player| player.total_book_value == max_book_value }
  end

  def switch_player
    index = players.index(current_player)
    self.current_player = players[(index + 1) % players.count]
  end

  def run_transaction(opponent_id, rank)
    opponent = players[opponent_id.to_i]
    return opponent_transaction(opponent, rank) if opponent.hand_has_rank?(rank)
    return pond_transaction(opponent, rank) unless deck.cards_count.zero?

    RoundResult.new(player: current_player, opponent: opponent, rank: rank, fished: true, empty_pond: true)
  end

  def opponent_transaction(opponent, rank)
    cards = opponent.remove_cards_with_rank(rank)
    current_player.add_to_hand(cards)
    RoundResult.new(player: current_player, opponent: opponent, rank: rank, got_rank: true,
                    amount: integer_to_string(cards.count))
  end

  def pond_transaction(opponent, rank)
    card = deck.deal
    current_player.add_to_hand(card)
    if card.rank == rank
      return RoundResult.new(player: current_player, opponent: opponent, rank: rank, fished: true, got_rank: true)
    end

    RoundResult.new(player: current_player, opponent: opponent, rank: rank, fished: true, card_gotten: card.rank)
  end

  def integer_to_string(integer)
    return 'zero' if integer.zero?
    return 'one' if integer == 1
    return 'two' if integer == 2
    return 'three' if integer == 3

    'several' if integer >= 4
  end

  def session_player_json(session_player)
    correct_player = players.detect { |player| player == session_player }
    correct_player.as_json
  end
end
