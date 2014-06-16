status :draft
satisfies_need "100986"

multiple_choice :how_old? do
  option '18-or-over' => :exception_to_limits?
  option 'under-18' => :not_old_enough
end

multiple_choice :exception_to_limits? do
  option "yes" => :investigate_specific_rules
  option "no" => :how_many_night_hours_worked?
end

value_question :how_many_night_hours_worked? do
  next_node_if(:taken_rest_period?) { |hours| hours.to_i > 3 }
  next_node_if(:not_a_night_worker) { |hours| hours.to_i > 1 }
  next_node { raise SmartAnswer::InvalidResponse }
end

multiple_choice :taken_rest_period? do
  option "yes" => :break_between_shifts?
  option "no" => :limit_exceeded
end

multiple_choice :break_between_shifts? do
  option "yes" => :reference_period?
  option "no" => :limit_exceeded
end

value_question :reference_period? do
  calculate :weeks_worked do
    weeks = Integer(responses.last)
    if weeks < 1 or weeks > 52
      raise SmartAnswer::InvalidResponse
    end
    weeks
  end

  save_input_as :weeks_worked

  next_node :weeks_of_leave?
end

value_question :weeks_of_leave? do
  calculate :weeks_leave do
    if Integer(responses.last) >= weeks_worked
      raise SmartAnswer::InvalidResponse
    end
    responses.last.to_i
  end

  save_input_as :weeks_leave

  next_node :what_is_your_work_cycle?
end

value_question :what_is_your_work_cycle? do
  calculate :work_cycle do
    Integer(responses.last)
  end

  save_input_as :work_cycle

  next_node :nights_per_cycle?
end

value_question :nights_per_cycle? do
  calculate :nights_in_cycle do
    if Integer(responses.last) > work_cycle
      raise SmartAnswer::InvalidResponse
    end
    responses.last.to_i
  end

  save_input_as :nights_in_cycle

  next_node :hours_per_night?
end

value_question :hours_per_night? do
  calculate :hours_per_shift do
    Integer(responses.last)
  end

  save_input_as :hours_per_shift

  next_node_if(:not_a_night_worker) { |hours| hours.to_i < 4 }
  next_node_if(:limit_exceeded) { |hours| hours.to_i > 13 }
  next_node(:overtime_hours?)
end

value_question :overtime_hours? do
  calculate :overtime_hours do
    Integer(responses.last)
  end

  calculate :calculator do
    Calculators::NightWorkHours.new(
      weeks_worked: weeks_worked, weeks_leave: weeks_leave,
      work_cycle: work_cycle, nights_in_cycle: nights_in_cycle,
      hours_per_shift: hours_per_shift, overtime_hours: overtime_hours
    )
  end

  calculate :average_hours do
    calculator.average_hours
  end

  calculate :potential_days do
    calculator.potential_days
  end

  next_node_if(:within_legal_limit) do |response|
    calculator = Calculators::NightWorkHours.new(
      weeks_worked: weeks_worked, weeks_leave: weeks_leave,
      work_cycle: work_cycle, nights_in_cycle: nights_in_cycle,
      hours_per_shift: hours_per_shift, overtime_hours: response.to_i
    )

    calculator.average_hours < 9
  end
  next_node(:outside_legal_limit)
end

outcome :not_old_enough
outcome :investigate_specific_rules
outcome :not_a_night_worker
outcome :limit_exceeded
outcome :within_legal_limit
outcome :outside_legal_limit
