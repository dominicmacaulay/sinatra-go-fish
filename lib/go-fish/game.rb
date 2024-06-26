# frozen_string_literal: false

require_relative 'deck'
require_relative 'round_result'

# go fish game class
class Game
  PLAYER_CAPACITY = 2
  MINIMUM_BOOK_LENGTH = 4
  attr_reader :players, :deal_number, :deck_cards
  attr_accessor :current_player, :started

  def initialize(players = [], deal_number: 5, deck_cards: nil)
    @players = players
    @deal_number = deal_number
    @deck_cards = deck_cards
    @current_player = nil
    @started = false
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

  def play_round(opponent_api_key, rank)
    opponent = find_player_by_api(opponent_api_key)
    message = run_transaction(opponent, rank)
    message.book_was_made if current_player.make_book?
    switch_player unless message.got_rank
    check_for_winners
    message
  end

  def check_for_winners
    return unless players.map(&:hand_count).sum.zero? && deck.cards.empty?

    self.winners = determine_winners
  end

  def as_json
    { players: players.map(&:as_json),
      deck: deck.as_json,
      deal_number: deal_number,
      current_player: current_player&.as_json,
      started: started }
  end

  private

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

  def find_player_by_api(api_key)
    players.detect { |player| player.api_key == api_key }
  end
end
