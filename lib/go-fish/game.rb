# frozen_string_literal: false

# TODO: rewrite this class
require_relative 'deck'
require_relative 'round_result'

# go fish game class
class Game
  MINIMUM_BOOK_LENGTH = 4

  attr_reader :deck_cards, :players, :winner, :deal_number
  attr_accessor :current_player, :winners, :started

  def initialize(players = [], deck_cards: nil, deal_number: 5)
    @deal_number = deal_number
    @deck_cards = deck_cards
    @players = players
    @winners = nil
    @current_player = nil
    @started = false
  end

  def deck
    @deck ||= deck_cards.nil? ? Deck.new : Deck.new(cards: deck_cards)
  end

  def add_player(player)
    players.push(player)
  end

  def empty?
    players.empty?
  end

  def start
    deck.shuffle
    deal_number.times do
      players.each { |player| player.add_to_hand(deck.deal) }
    end
    self.current_player = players.first
    self.started = true
  end

  def deal_to_player_if_necessary
    return nil unless current_player.hand_count.zero?

    if deck.cards_count.zero?
      @current_player = next_player
      return 'Sorry. Your hand is empty and there are no cards in the pond. You will have to sit this one out.'
    end
    deal_number.times { current_player.add_to_hand(deck.deal) }
    'Your hand was empty, but you received cards from the pond!'
  end

  def retrieve_opponents
    opponents = players.map { |player| player if player != current_player }.compact
    ShowInfo.new(opponents: opponents)
  end

  def validate_rank_choice(rank)
    return 'This is an acceptable choice.' if current_player.hand_has_rank?(rank)

    'You have chosen foolishly. Choose again: '
  end

  def match_player_name(name)
    named_player = players.detect do |player|
      player.name == name && player != current_player
    end
    named_player.nil? ? "Do you see '#{name}' among your opponents? Try again: " : named_player
  end

  def play_round(opponent, rank)
    message = run_transaction(opponent, rank)
    message.book_was_made if current_player.make_book?
    switch_player unless message.got_rank
    check_for_winners
    message
  end

  def display_winners
    winners.count > 1 ? tie_message_for_multiple_winners(winners) : single_winner_message(winners.first)
  end

  def check_for_winners
    return unless players.map(&:hand_count).sum.zero? && deck.cards.empty?

    self.winners = determine_winners
  end

  private

  def single_winner_message(winner)
    "#{winner.name} won the game with #{winner.book_count} books totalling in #{winner.total_book_value}"
  end

  def tie_message_for_multiple_winners(winners)
    message = ''
    winners.each do |winner|
      message.concat('and ') if winner == winners.last
      message.concat("#{winner.name} ")
      message.concat(', ') if winner != winners.last && winner != winners[-2]
    end
    message.concat("tied with #{winners.first.book_count} books totalling in #{winners.first.total_book_value}")
  end

  def determine_winners
    possible_winners = players_with_highest_book_count
    player_with_highest_book_value(possible_winners)
  end

  def player_with_highest_book_value(players)
    maximum_value = 0
    players.each do |player|
      maximum_value = player.total_book_value if player.total_book_value > maximum_value
    end
    players.select { |player| player.total_book_value == maximum_value }
  end

  def players_with_highest_book_count
    maximum_value = 0
    players.each do |player|
      maximum_value = player.book_count if player.book_count > maximum_value
    end
    players.select { |player| player.book_count == maximum_value }
  end

  def switch_player
    index = players.index(current_player)
    self.current_player = players[(index + 1) % players.count]
  end

  def next_player
    index = players.index(current_player)
    self.current_player = players[(index + 1) % players.count]
  end

  def run_transaction(opponent, rank)
    return opponent_transaction(opponent, rank) if opponent.hand_has_rank?(rank)
    return pond_transaction(opponent, rank) unless deck.cards_count.zero?

    pond_empty(opponent, rank)
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
    if card.equal_rank?(rank)
      RoundResult.new(player: current_player, opponent: opponent, rank: rank, fished: true, got_rank: true)
    else
      RoundResult.new(player: current_player, opponent: opponent, rank: rank, fished: true, card_gotten: card.rank)
    end
  end

  def pond_empty(opponent, rank)
    RoundResult.new(player: current_player, opponent: opponent, rank: rank, fished: true, empty_pond: true)
  end

  def integer_to_string(integer)
    return 'one' if integer == 1
    return 'two' if integer == 2
    return 'three' if integer == 3

    'several'
  end
end
