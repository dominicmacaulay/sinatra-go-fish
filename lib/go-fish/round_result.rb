# frozen_string_literal: false

# round result class
class RoundResult
  attr_reader :current_player, :opponent, :rank, :fished, :got_rank, :card_gotten, :amount, :empty_pond
  attr_accessor :book_made

  def initialize(player:, opponent:, rank:, fished: false, got_rank: false, card_gotten: nil, # rubocop:disable Metrics/ParameterLists,Metrics/MethodLength
                 amount: 'one', empty_pond: false)
    @current_player = player
    @opponent = opponent
    @rank = rank
    @fished = fished
    @got_rank = got_rank
    @card_gotten = card_gotten
    @amount = amount
    @empty_pond = empty_pond
    @book_made = false
  end

  def display_for(player)
    message = current_player_message if player == current_player

    message = opponent_message if player == opponent

    message = other_player_message unless player == current_player || player == opponent

    message.concat book_made ? ', then created a book with them.' : '.'

    message
  end

  def ==(other) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    # first check that the required parameters are equal
    return false unless other.current_player == current_player && other.opponent == opponent && other.rank == rank
    # then check if case 1 variables are equal
    return false unless other.fished == fished && other.got_rank == got_rank
    # then check if case 2 and 3 variables are equal
    return false unless other.card_gotten == card_gotten && other.amount == amount
    # then check if case 4 variables are equal
    return false unless other.empty_pond == empty_pond
    # then check if book_was_made is the same
    return false unless other.book_made == book_made

    true
  end

  def book_was_made
    self.book_made = true
  end

  private

  def current_player_message
    message = "You asked #{opponent.name} for #{rank}'s and "
    message.concat(fished_message)
    message.concat(got_cards_message(reveal_card: true))
  end

  def opponent_message
    message = "#{current_player.name} asked you for #{rank}'s and "
    message.concat(fished_message)
    message.concat(got_cards_message)
  end

  def other_player_message
    message = "#{current_player.name} asked #{opponent.name} for #{rank}'s and "
    message.concat(fished_message)
    message.concat(got_cards_message)
  end

  def fished_message
    fished == true ? 'went fishing and ' : ''
  end

  def got_cards_message(reveal_card: false)
    if got_rank
      "got #{amount} of them"
    elsif !empty_pond
      reveal_card ? "got a #{card_gotten}" : 'had no luck'
    else
      'got nothing! The pond is empty'
    end
  end
end
