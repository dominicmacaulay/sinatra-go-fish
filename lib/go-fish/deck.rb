# frozen_string_literal: true

require_relative 'card'

# go fish deck class
class Deck
  attr_accessor :cards

  def initialize(cards: make_cards)
    @cards = cards
  end

  def shuffle(seed = Random.new)
    cards.shuffle!(random: seed)
  end

  def deal
    cards.shift
  end

  def clear_cards
    self.cards = []
  end

  def cards_count
    cards.count
  end

  private

  def make_cards
    Card::SUITS.flat_map do |suit|
      Card::RANKS.map do |rank|
        Card.new(rank, suit)
      end
    end
  end
end
