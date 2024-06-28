# frozen_string_literal: false

class ShowInfo # rubocop:disable Style/Documentation
  attr_reader :cards, :opponents

  def initialize(cards: nil, opponents: nil)
    @cards = cards
    @opponents = opponents
  end

  def display
    return show_cards unless cards.nil?

    show_opponents unless opponents.nil?
  end

  def ==(other)
    return false unless cards == other.cards
    return false unless opponents == other.opponents

    true
  end

  private

  def show_cards
    message = 'You have '
    cards.each do |card|
      message.concat('and ') if card == cards.last && card != cards.first
      message.concat("a #{card.rank} of #{card.suit}")
      message.concat(', ') unless card == cards.last
    end
    message
  end

  def show_opponents
    message = 'Your opponents are '
    opponents.each do |opponent|
      message.concat('and ') if opponent == opponents.last && opponent != opponents.first
      message.concat(opponent.name.to_s)
      message.concat(', ') unless opponent == opponents.last
    end
    message
  end
end
