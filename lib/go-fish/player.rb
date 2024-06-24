# frozen_string_literal: true

# player class
class Player
  attr_reader :name, :api_key

  def initialize(name, api_key)
    @name = name
    @api_key = api_key
  end
end
