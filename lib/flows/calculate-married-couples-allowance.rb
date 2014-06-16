status :published
satisfies_need "101007"

multiple_choice :were_you_or_your_partner_born_on_or_before_6_april_1935? do
  option yes: :did_you_marry_or_civil_partner_before_5_december_2005?
  option no: :sorry

  calculate :is_before_april_changes do
    Date.today < Date.civil(2014, 04, 06)
  end

  calculate :personal_allowance do
    is_before_april_changes ? 9440 : 10000
  end

  calculate :earner_limit do
    is_before_april_changes ? 26100.0 : 27000.0
  end

  calculate :age_related_allowance_chooser do
    AgeRelatedAllowanceChooser.new(
      personal_allowance: personal_allowance,
      over_65_allowance: 10500,
      over_75_allowance: 10660
    )
  end

  calculate :calculator do
    MarriedCouplesAllowanceCalculator.new(
      maximum_mca: (is_before_april_changes ? 7915 : 8165),
      minimum_mca: (is_before_april_changes ? 3040 : 3140),
      income_limit: (is_before_april_changes ? 26100 : 27000),
      personal_allowance: personal_allowance,
      validate_income: false
    )
  end
end

multiple_choice :did_you_marry_or_civil_partner_before_5_december_2005? do
  option yes: :whats_the_husbands_date_of_birth?
  option no: :whats_the_highest_earners_date_of_birth?

  calculate :income_measure do
    case responses.last
    when 'yes' then "husband"
    when 'no' then "highest earner"
    else
      raise SmartAnswer::InvalidResponse
    end
  end
end

date_question :whats_the_husbands_date_of_birth? do
  to { Date.parse('1 Jan 1896') }
  from { Date.today }

  save_input_as :birth_date
  next_node :whats_the_husbands_income?
end

date_question :whats_the_highest_earners_date_of_birth? do
  to { Date.parse('1 Jan 1896') }
  from { Date.today }

  save_input_as :birth_date
  next_node :whats_the_highest_earners_income?
end

money_question :whats_the_husbands_income? do
  save_input_as :income

  calculate :income_greater_than_0 do
    raise SmartAnswer::InvalidResponse if responses.last < 1
  end

  next_node_if(:paying_into_a_pension?) { |r| r.to_f >= earner_limit }
  next_node(:husband_done)
end

money_question :whats_the_highest_earners_income? do
  save_input_as :income

  calculate :income_greater_than_0 do
    raise SmartAnswer::InvalidResponse if responses.last < 1
  end

  next_node_if(:paying_into_a_pension?) { |r| r.to_f >= earner_limit }
  next_node(:highest_earner_done)
end

multiple_choice :paying_into_a_pension? do
  option yes: :how_much_expected_contributions_before_tax?
  option no: :how_much_expected_gift_aided_donations?
end

money_question :how_much_expected_contributions_before_tax? do
  save_input_as :gross_pension_contributions

  next_node :how_much_expected_contributions_with_tax_relief?
end

money_question :how_much_expected_contributions_with_tax_relief? do
  save_input_as :net_pension_contributions

  next_node :how_much_expected_gift_aided_donations?
end

money_question :how_much_expected_gift_aided_donations? do
  calculate :income do
    calculator.calculate_adjusted_net_income(income.to_f, (gross_pension_contributions.to_f || 0), (net_pension_contributions.to_f || 0), responses.last)
  end

  next_node_if(:husband_done) { income_measure == "husband" }
  next_node(:highest_earner_done)
end

outcome :husband_done do
  precalculate :allowance do
    age_related_allowance = age_related_allowance_chooser.get_age_related_allowance(Date.parse(birth_date))
    calculator.calculate_allowance(age_related_allowance, income)
  end
end
outcome :highest_earner_done do
  precalculate :allowance do
    age_related_allowance = age_related_allowance_chooser.get_age_related_allowance(Date.parse(birth_date))
    calculator.calculate_allowance(age_related_allowance, income)
  end
end
outcome :sorry
