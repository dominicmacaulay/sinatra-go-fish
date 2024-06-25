# frozen_string_literal: true

# Book class
class Book
  attr_reader :cards

  def initialize(cards)
    @cards = cards
  end

  def value
    @value ||= cards.first.value
  end

  def as_json
    {
      cards: cards.map(&:to_json)
    }
  end
end
