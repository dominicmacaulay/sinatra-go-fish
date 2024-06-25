# frozen_string_literal: false

require_relative 'deck'
require_relative 'round_result'

# go fish game class
class Game
  attr_reader :players, :deal_number
  attr_accessor :current_player, :started

  def initialize(players = [], deal_number: 5)
    @players = players
    @deal_number = deal_number
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
    @deck ||= Deck.new
  end

  def start
    deck.shuffle
    deal_number.times do
      players.each { |player| player.add_to_hand(deck.deal) }
    end
    self.current_player = players.first
    self.started = true
  end

  def as_json
    {
      players: players.map(&:as_json),
      deck: deck.as_json,
      deal_number: deal_number,
      current_player: current_player&.as_json,
      started: started
    }
  end
end
