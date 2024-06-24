# frozen_string_literal: true

class Game # rubocop:disable Style/Documentation
  attr_reader :players

  def initialize
    @players = []
  end

  def add_player(player)
    players.push(player)
  end

  def empty?
    players.empty?
  end
end
