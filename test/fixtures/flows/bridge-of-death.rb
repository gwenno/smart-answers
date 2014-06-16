status :draft

value_question :what_is_your_name? do
  save_input_as :your_name
  next_node :what_is_your_quest?
end

multiple_choice :what_is_your_quest? do
  option :to_seek_the_holy_grail
  option :to_rescue_the_princess
  option :dunno

  next_node_if(:what_is_the_capital_of_assyria?) do |response|
    your_name =~ /robin/i and response == 'to_seek_the_holy_grail'
  end
  next_node(:what_is_your_favorite_colour?)
end

value_question :what_is_the_capital_of_assyria? do
  save_input_as :capital_of_assyria
  next_node :auuuuuuuugh
end

multiple_choice :what_is_your_favorite_colour? do
  option blue: :done
  option blue_no_yellow: :auuuuuuuugh
  option red: :done
end

outcome :done
outcome :auuuuuuuugh
