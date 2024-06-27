# frozen_string_literal: false

require_relative 'show_info'
require_relative 'book'
require_relative 'game'

# go fish player class
class Player
  MINIMUM_NAME_LENGTH = 3

  attr_reader :name, :api_key, :hand, :books

  def initialize(name, api_key, hand: [], books: [])
    @name = name
    @api_key = api_key
    @hand = hand
    @books = books
  end

  def add_to_hand(cards)
    hand.push(*cards)
  end

  def hand_count
    hand.count
  end

  def book_count
    books.count
  end

  def total_book_value
    books.map(&:value).sum
  end

  def hand_has_rank?(rank)
    hand.each do |card|
      return true if card.equal_rank?(rank)
    end
    false
  end

  def remove_cards_with_rank(rank)
    cards = hand.dup
    hand.delete_if { |card| card.equal_rank?(rank) }
    cards.select { |card| card.equal_rank?(rank) }
  end

  def rank_count(rank)
    hand.select { |card| card.equal_rank?(rank) }.count
  end

  def show_hand
    ShowInfo.new(cards: hand)
  end

  def make_book?
    unique_cards = find_unique_cards
    unique_cards.each do |unique_card|
      create_book(unique_card.rank) if rank_count(unique_card.rank) >= Game::MINIMUM_BOOK_LENGTH
    end
    unique_cards != find_unique_cards
  end

  def ==(other)
    other.api_key == api_key
  end

  def as_json(show_everything)
    json = { name: name, books: books.map(&:as_json) }
    if show_everything
      json[api_key] = api_key
      json[hand] = hand.map(&:as_json)
    end
    json
  end

  private

  def find_unique_cards
    hand.uniq(&:rank)
  end

  def create_book(rank)
    cards = hand.select { |card| card.equal_rank?(rank) }
    hand.delete_if { |card| cards.include?(card) }
    books << Book.new(cards)
  end
end
