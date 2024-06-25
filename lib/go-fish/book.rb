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
end
