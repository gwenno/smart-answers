days_of_the_week = Calculators::MaternityPaternityCalculatorV2::DAYS_OF_THE_WEEK

## QP0
multiple_choice :leave_or_pay_for_adoption? do
  option yes: :employee_date_matched_paternity_adoption?
  option no: :baby_due_date_paternity?

  calculate :adoption do
    responses.last == 'yes'
  end

  calculate :leave_type do
    responses.last == 'yes' ? 'paternity_adoption' : 'paternity'
  end
end

## QP1
date_question :baby_due_date_paternity? do
  calculate :due_date do
    Date.parse(responses.last)
  end

  calculate :calculator do
    Calculators::MaternityPaternityCalculatorV2.new(due_date, 'paternity')
  end

  next_node :baby_birth_date_paternity?
end

## QAP1 - Paternity Adoption
date_question :employee_date_matched_paternity_adoption? do
  calculate :matched_date do
    Date.parse(responses.last)
  end

  calculate :calculator do
    Calculators::MaternityPaternityCalculatorV2.new(matched_date, 'paternity_adoption')
  end

  next_node :padoption_date_of_adoption_placement?
end

## QP2
date_question :baby_birth_date_paternity? do
  calculate :date_of_birth do
    Date.parse(responses.last)
  end

  calculate :calculator do
    calculator.date_of_birth = date_of_birth
    calculator
  end

  next_node :employee_responsible_for_upbringing?
end

## QAP2 - Paternity Adoption
date_question :padoption_date_of_adoption_placement? do

  calculate :ap_adoption_date do
    placement_date = Date.parse(responses.last)
    raise SmartAnswer::InvalidResponse if placement_date < matched_date
    calculator.adoption_placement_date = placement_date
    placement_date
  end

  calculate :ap_adoption_date_formatted do
    calculator.format_date_day ap_adoption_date
  end

  calculate :matched_date_formatted do
    calculator.format_date_day matched_date
  end

  next_node :padoption_employee_responsible_for_upbringing?
end

## QP3
multiple_choice :employee_responsible_for_upbringing? do
  option yes: :employee_work_before_employment_start?
  option no: :paternity_not_entitled_to_leave_or_pay
  save_input_as :paternity_responsible

  calculate :employment_start do
    calculator.employment_start
  end

  calculate :employment_end do
    due_date
  end

  calculate :p_notice_leave do
    calculator.notice_of_leave_deadline
  end
end

## QAP3 - Paternity Adoption
multiple_choice :padoption_employee_responsible_for_upbringing? do
  option yes: :employee_work_before_employment_start? # Combined flow
  option no: :paternity_not_entitled_to_leave_or_pay
  save_input_as :paternity_responsible

  calculate :employment_start do
    calculator.a_employment_start
  end

  calculate :employment_end do
    matched_date
  end
end

## QP4 - Shared flow onwards
multiple_choice :employee_work_before_employment_start? do
  option yes: :employee_has_contract_paternity?
  option no: :paternity_not_entitled_to_leave_or_pay
  save_input_as :paternity_employment_start ## Needed only in outcome
end

## QP5
multiple_choice :employee_has_contract_paternity? do
  option :yes
  option :no
  save_input_as :has_contract

  next_node :employee_on_payroll_paternity?
end

## QP6
multiple_choice :employee_on_payroll_paternity? do
  option yes: :employee_still_employed_on_birth_date?
  option :no
  save_input_as :on_payroll

  calculate :leave_spp_claim_link do
    adoption ? 'adoption' : 'notice-period'
  end

  calculate :not_entitled_reason do
    if responses.last == 'no' && has_contract == 'no'
      PhraseList.new << :paternity_not_entitled_to_leave <<
                        :paternity_not_entitled_to_pay_intro <<
                        :must_be_on_payroll <<
                        :paternity_not_entitled_to_pay_outro
    end
  end

  calculate :to_saturday do
    if adoption
      calculator.format_date_day calculator.matched_week.last
    else
      calculator.format_date_day calculator.qualifying_week.last
    end
  end

  calculate :still_employed_date do
    adoption ? calculator.employment_end : date_of_birth
  end

  calculate :start_leave_hint do
    adoption ? ap_adoption_date_formatted : date_of_birth
  end

  next_node_if(:paternity_not_entitled_to_leave_or_pay, variable_matches(:has_contract, 'no'))
  next_node :employee_start_paternity?
end

## QP7
multiple_choice :employee_still_employed_on_birth_date? do
  option :yes
  option :no
  save_input_as :employed_dob

  calculate :not_entitled_reason do
    if responses.last == 'no' and has_contract == 'no'
      PhraseList.new << :paternity_not_entitled_to_leave <<
                        :paternity_not_entitled_to_pay_intro <<
                        :"#{leave_type}_must_be_employed_by_you" <<
                        :paternity_not_entitled_to_pay_outro
    end
  end

  next_node_if(:paternity_not_entitled_to_leave_or_pay, variable_matches(:has_contract, 'no') & responded_with('no'))
  next_node :employee_start_paternity?
end

## QP8
date_question :employee_start_paternity? do
  from { 2.years.ago(Date.today) }
  to { 2.years.since(Date.today) }

  save_input_as :employee_leave_start

  calculate :leave_start_date do
    calculator.leave_start_date = Date.parse(responses.last)
    if adoption
      raise SmartAnswer::InvalidResponse if calculator.leave_start_date < ap_adoption_date
    else
      raise SmartAnswer::InvalidResponse if calculator.leave_start_date < date_of_birth
    end
    calculator.leave_start_date
  end

  calculate :notice_of_leave_deadline do
    calculator.notice_of_leave_deadline
  end

  next_node :employee_paternity_length?
end

## QP9
multiple_choice :employee_paternity_length? do
  option :one_week
  option :two_weeks
  save_input_as :leave_amount

  calculate :leave_end_date do
    unless leave_start_date.nil?
      if responses.last == 'one_week'
        1.week.since(leave_start_date)
      else
        2.weeks.since(leave_start_date)
      end
    end
  end

  calculate :not_entitled_reason do
    if has_contract == 'yes'
      if employed_dob == 'no'
        PhraseList.new << :paternity_entitled_to_leave <<
                          :paternity_not_entitled_to_pay_intro <<
                          :"#{leave_type}_must_be_employed_by_you" <<
                          :paternity_not_entitled_to_pay_outro
      elsif on_payroll == 'no'
        PhraseList.new << :paternity_entitled_to_leave <<
                          :paternity_not_entitled_to_pay_intro <<
                          :must_be_on_payroll <<
                          :paternity_not_entitled_to_pay_outro
      end
    end
  end

  next_node_if(:paternity_not_entitled_to_leave_or_pay, variable_matches(:has_contract, 'yes') &
    (variable_matches(:on_payroll, 'no') | variable_matches(:employed_dob, 'no')))
  next_node :last_normal_payday_paternity?
end

## QP10
date_question :last_normal_payday_paternity? do
  from { 2.years.ago(Date.today) }
  to { 2.years.since(Date.today) }

  calculate :calculator do
    calculator.last_payday = Date.parse(responses.last)
    raise SmartAnswer::InvalidResponse if calculator.last_payday > Date.parse(to_saturday)
    calculator
  end

  next_node :payday_eight_weeks_paternity?
end

## QP11
date_question :payday_eight_weeks_paternity? do
  from { 2.years.ago(Date.today) }
  to { 2.years.since(Date.today) }

  precalculate :payday_offset do
    calculator.payday_offset
  end

  calculate :pre_offset_payday do
    payday = Date.parse(responses.last)
    raise SmartAnswer::InvalidResponse if payday > calculator.payday_offset
    calculator.pre_offset_payday = payday
    payday
  end

  calculate :relevant_period do
    calculator.formatted_relevant_period
  end

  next_node :pay_frequency_paternity?
end

## QP12
multiple_choice :pay_frequency_paternity? do
  option weekly: :earnings_for_pay_period_paternity?
  option every_2_weeks: :earnings_for_pay_period_paternity?
  option every_4_weeks: :earnings_for_pay_period_paternity?
  option monthly: :earnings_for_pay_period_paternity?
  save_input_as :pay_pattern

  calculate :calculator do
    calculator.pay_method = responses.last
    calculator
  end

end

## QP13
money_question :earnings_for_pay_period_paternity? do
  save_input_as :earnings

  next_node_calculation :calculator do |response|
    calculator.calculate_average_weekly_pay(pay_pattern, response)
    calculator
  end

  average_weekly_earnings_under_lower_earning_limit = SmartAnswer::Predicate::Callable.new("average weekly earnings under lower earning limit") do
    calculator.average_weekly_earnings < calculator.lower_earning_limit
  end

  next_node_if(:paternity_leave_and_pay, average_weekly_earnings_under_lower_earning_limit)
  next_node :how_do_you_want_the_spp_calculated?
end

## QP14
multiple_choice :how_do_you_want_the_spp_calculated? do
  option :weekly_starting
  option :usual_paydates

  save_input_as :spp_calculation_method

  calculate :paternity_info do
    if responses.last == "weekly_starting"
      phrases = PhraseList.new
      if has_contract == "no"
        phrases << :paternity_not_entitled_to_leave
      else
        phrases << :paternity_entitled_to_leave
      end
      phrases << :paternity_entitled_to_pay << :"#{leave_type}_spp_claim_link"
      phrases
    end
  end

  next_node_if(:paternity_leave_and_pay, responded_with('weekly_starting'))
  next_node_if(:monthly_pay_paternity?, variable_matches(:pay_pattern, 'monthly'))
  next_node :next_pay_day_paternity?
end

## QP15
date_question :next_pay_day_paternity? do
  from { 2.years.ago(Date.today) }
  to { 2.years.since(Date.today) }
  save_input_as :next_pay_day

  calculate :calculator do
    calculator.pay_date = Date.parse(responses.last)
    calculator
  end
  next_node :paternity_leave_and_pay
end

## QP16
multiple_choice :monthly_pay_paternity? do
  option first_day_of_the_month: :paternity_leave_and_pay
  option last_day_of_the_month: :paternity_leave_and_pay
  option specific_date_each_month: :specific_date_each_month_paternity?
  option last_working_day_of_the_month: :days_of_the_week_paternity?
  option a_certain_week_day_each_month: :day_of_the_month_paternity?

  save_input_as :monthly_pay_method
end

## QP17
value_question :specific_date_each_month_paternity? do

  calculate :pay_day_in_month do
    day = responses.last.to_i
    raise InvalidResponse unless day > 0 and day < 32
    calculator.pay_day_in_month = day
  end

  next_node :paternity_leave_and_pay
end

## QP18
checkbox_question :days_of_the_week_paternity? do
  (0...days_of_the_week.size).each { |i| option i.to_s.to_sym }

  calculate :last_day_in_week_worked do
    calculator.work_days = responses.last.split(",").map(&:to_i)
    calculator.pay_day_in_week = responses.last.split(",").sort.last.to_i
  end
  next_node :paternity_leave_and_pay
end

## QP19
multiple_choice :day_of_the_month_paternity? do
  option :"0"
  option :"1"
  option :"2"
  option :"3"
  option :"4"
  option :"5"
  option :"6"

  calculate :pay_day_in_week do
    calculator.pay_day_in_week = responses.last.to_i
    responses.last
  end

  next_node :pay_date_options_paternity?
end

## QP20
multiple_choice :pay_date_options_paternity? do
  option :"first"
  option :"second"
  option :"third"
  option :"fourth"
  option :"last"

  calculate :pay_week_in_month do
    calculator.pay_week_in_month = responses.last
  end

  next_node :paternity_leave_and_pay
end

# Paternity outcomes
outcome :paternity_leave_and_pay do

  precalculate :pay_method do
    calculator.pay_method = (
      if monthly_pay_method
        if monthly_pay_method == 'specific_date_each_month' and pay_day_in_month > 28
          'last_day_of_the_month'
        else
          monthly_pay_method
        end
      elsif spp_calculation_method == 'weekly_starting'
        spp_calculation_method
      else
        pay_pattern
      end
    )
  end

  precalculate :above_lower_earning_limit? do
    calculator.average_weekly_earnings > calculator.lower_earning_limit
  end

  precalculate :paternity_info do
    if paternity_info.nil?
      phrases = PhraseList.new

      if has_contract == "no"
        phrases << :paternity_not_entitled_to_leave
      else
        phrases << :paternity_entitled_to_leave
      end

      unless above_lower_earning_limit?
        phrases << :paternity_not_entitled_to_pay_intro <<
                    :must_earn_over_threshold <<
                    :paternity_not_entitled_to_pay_outro
      else
        phrases << :paternity_entitled_to_pay << :"#{leave_type}_spp_claim_link"
      end
      phrases
    else
      paternity_info
    end
  end

  precalculate :lower_earning_limit do
    sprintf("%.2f", calculator.lower_earning_limit)
  end

  precalculate :entitled_to_pay? do
    !paternity_info.nil? && paternity_info.phrase_keys.include?(:paternity_entitled_to_pay)
  end

  precalculate :pay_dates_and_pay do
    rows = []
    if entitled_to_pay? && above_lower_earning_limit?
      calculator.paydates_and_pay.each do |date_and_pay|
        rows << %Q(#{date_and_pay[:date].strftime("%e %B %Y")}|£#{sprintf("%.2f", date_and_pay[:pay])})
      end
    end
    rows.join("\n")
  end

  precalculate :total_spp do
    if above_lower_earning_limit?
      sprintf("%.2f", calculator.total_statutory_pay)
    end
  end

  precalculate :average_weekly_earnings do
    sprintf("%.2f", calculator.average_weekly_earnings)
  end

end

outcome :paternity_not_entitled_to_leave_or_pay do
  precalculate :not_entitled_reason do
    if not_entitled_reason.nil?
      phrases = PhraseList.new
      phrases << :paternity_not_entitled_to_leave_or_pay_intro
      phrases << :"#{leave_type}_not_responsible_for_upbringing" if paternity_responsible == 'no'
      phrases << :not_worked_long_enough if paternity_employment_start == "no"
      phrases << :paternity_entitled_to_leave if on_payroll == "no"
      phrases << :paternity_not_entitled_to_pay_a if has_contract == "no"
      phrases << :paternity_not_entitled_to_leave_or_pay_outro
      phrases
    else
      not_entitled_reason
    end
  end
end
