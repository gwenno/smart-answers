status :published
satisfies_need "100131"

data_query = Calculators::PassportAndEmbassyDataQuery.new

exclude_countries = %w(holy-see british-antarctic-territory)

# Q1
country_select :which_country_are_you_in?, exclude_countries: exclude_countries do
  save_input_as :current_location

  calculate :location do
    loc = WorldLocation.find(current_location)
    if Calculators::PassportAndEmbassyDataQuery::ALT_EMBASSIES.has_key?(current_location)
      loc = WorldLocation.find(Calculators::PassportAndEmbassyDataQuery::ALT_EMBASSIES[current_location])
    end
    raise InvalidResponse unless loc
    loc
  end

  next_node_if(:cannot_apply, data_query.ineligible_country?)
  next_node_if(:which_opt?, responded_with('the-occupied-palestinian-territories'))
  next_node_if(:apply_in_neighbouring_country, data_query.apply_in_neighbouring_countries?)
  next_node(:renewing_replacing_applying?)
end

# Q1a
multiple_choice :which_opt? do
  option :gaza
  option :"jerusalem-or-westbank"

  save_input_as :current_location
  next_node :renewing_replacing_applying?
end

# Q2
multiple_choice :renewing_replacing_applying? do
  option :renewing_new
  option :renewing_old
  option :applying
  option :replacing

  save_input_as :application_action

  precalculate :organisation do
    location.fco_organisation
  end

  calculate :overseas_passports_embassies do
    if organisation
      organisation.offices_with_service 'Overseas Passports Service'
    else
      []
    end
  end

  calculate :general_action do
    responses.last =~ /^renewing_/ ? 'renewing' : responses.last
  end

  calculate :passport_data do
    data_query.find_passport_data(current_location)
  end
  calculate :application_type do
    passport_data['type']
  end
  calculate :is_ips_application do
    data_query.ips_application?.call(self, nil)
  end
  calculate :ips_number do
    application_type.split("_")[2] if is_ips_application
  end

  calculate :application_form do
    passport_data['app_form']
  end

  calculate :supporting_documents do
    passport_data['group']
  end

  calculate :application_address do
    passport_data['address']
  end

  calculate :ips_docs_number do
    supporting_documents.split("_")[3] if is_ips_application
  end

  calculate :ips_result_type do
    passport_data['online_application'] ? :ips_application_result_online : :ips_application_result
  end

  data_query.passport_costs.each do |k, v|
    calculate "costs_#{k}".to_sym do
      v
    end
  end

  calculate :waiting_time do
    passport_data[application_action]
  end

  next_node :child_or_adult_passport?
end

# Q3
multiple_choice :child_or_adult_passport? do
  option :adult
  option :child

  save_input_as :child_or_adult

  calculate :fco_forms do
    if %w(nigeria).include?(current_location)
      PhraseList.new(:"#{responses.last}_fco_forms_nigeria")
    else
      PhraseList.new(:"#{responses.last}_fco_forms")
    end
  end

  on_condition(data_query.ips_application?) do
    next_node_if(:country_of_birth?, variable_matches(:application_action, %w(applying renewing_old)))
    next_node_if(:ips_application_result_online, variable_matches(:ips_result_type, :ips_application_result_online))
    next_node(:ips_application_result)
  end
  next_node_if(:fco_result, data_query.fco_application?)
  next_node(:result)
end

# Q4
country_select :country_of_birth?, include_uk: true, exclude_countries: exclude_countries do
  save_input_as :birth_location

  calculate :application_group do
    data_query.find_passport_data(responses.last)['group']
  end

  calculate :supporting_documents do
    responses.last == 'united-kingdom' ? supporting_documents : application_group
  end

  calculate :ips_docs_number do
    supporting_documents.split("_")[3]
  end

  on_condition(data_query.ips_application?) do
    next_node_if(:ips_application_result_online, variable_matches(:ips_result_type, :ips_application_result_online))
    next_node(:ips_application_result)
  end
  next_node_if(:fco_result, data_query.fco_application?)
  next_node(:result)
end

## Online IPS Application Result
outcome :ips_application_result_online do
  precalculate :how_long_it_takes do
    PhraseList.new(:"how_long_#{waiting_time}",
                   :"how_long_additional_info_#{application_action}",
                   :how_long_additional_time_online)
  end

  precalculate :cost do
    if application_action == 'replacing' and ips_number == '1' and ips_docs_number == '1'
      PhraseList.new(:"passport_courier_costs_replacing_ips#{ips_number}",
                     :"#{child_or_adult}_passport_costs_replacing_ips#{ips_number}")
    else
      PhraseList.new(:"passport_courier_costs_ips#{ips_number}",
                     :"#{child_or_adult}_passport_costs_ips#{ips_number}")
    end
  end
  precalculate :how_to_apply do
    PhraseList.new(:how_to_apply_online,
                   :"how_to_apply_online_prerequisites_#{general_action}",
                   :"how_to_apply_online_guidance_doc_group_#{ips_docs_number}")
  end
  precalculate :getting_your_passport do
    PhraseList.new(:"getting_your_passport_ips#{ips_number}")
  end
  precalculate :contact_passport_adviceline do
    PhraseList.new(:contact_passport_adviceline)
  end
end

## IPS Application Result
outcome :ips_application_result do
  precalculate :how_long_it_takes do
    phrases = PhraseList.new
    phrases << :"how_long_#{waiting_time}"
    phrases << :report_loss_or_theft if application_action == "replacing"
    phrases << :"how_long_it_takes_ips#{ips_number}"
    phrases
  end

  precalculate :cost do
    uk_visa_application_centre_countries = %w(algeria azerbaijan china georgia indonesia kazakhstan laos lebanon mauritania morocco nepal russia thailand ukraine venezuela western-sahara)
    pay_at_appointment_countries = %(venezuela)

    if application_action == 'replacing' and ips_number == '1' and ips_docs_number == '1'
      PhraseList.new(:"passport_courier_costs_replacing_ips#{ips_number}",
                    :"#{child_or_adult}_passport_costs_replacing_ips#{ips_number}",
                    :"passport_costs_ips#{ips_number}")
    else
      phrases = PhraseList.new
      if uk_visa_application_centre_countries.include?(current_location)
        phrases << :"passport_courier_costs_ips#{ips_number}_uk_visa"
      elsif %w(india pitcairn-island).include?(current_location)
        phrases << :"passport_courier_costs_ips3_#{current_location}"
      else
        phrases << :"passport_courier_costs_ips#{ips_number}"
      end
      phrases << :"#{child_or_adult}_passport_costs_ips#{ips_number}"

      if %w(bangladesh).include?(current_location)
        phrases << :"passport_costs_ips3_cash_or_card_#{current_location}" << :passport_costs_ips3_cash_or_card
      elsif data_query.cash_only_countries?(current_location)
        phrases << :passport_costs_ips_cash
      elsif pay_at_appointment_countries.include?(current_location)
        phrases << :passport_costs_pay_at_appointment
      else
        phrases << :"passport_costs_ips#{ips_number}"
      end
      phrases
    end
  end

  precalculate :how_to_apply do
    if passport_data['online_application']
    else
      phrases = PhraseList.new
      phrases <<  :"how_to_apply_ips#{ips_number}"
      if %w(pakistan).include?(current_location)
        phrases << :send_application_ips1_pakistan
      end
      phrases << application_form.to_sym
      phrases << supporting_documents.to_sym
      phrases
    end
  end

  precalculate :send_your_application do
    uk_visa_application_centre_countries = %w(afghanistan algeria azerbaijan burundi china gaza georgia indonesia kazakhstan laos lebanon mauritania morocco nepal russia thailand ukraine western-sahara venezuela)
    uk_visa_application_with_colour_pictures = %w(azerbaijan algeria china georgia indonesia kazakhstan laos lebanon mauritania morocco nepal thailand ukraine russia venezuela)
    non_uk_visa_application_with_colour_pictures = %w(belarus burma cuba sudan tajikistan turkmenistan uzbekistan)
    phrases = PhraseList.new
    if application_address
      phrases << :"send_application_#{application_address}"
    elsif uk_visa_application_centre_countries.include?(current_location)
      if %w(renewing_new).include?(application_action)
        if passport_data['application_office']
          if %w(western-sahara).include?(current_location)
            phrases << :send_application_uk_visa_renew_new_colour_western_sahara
          elsif uk_visa_application_with_colour_pictures.include?(current_location)
            phrases << :send_application_uk_visa_renew_new_colour
          else
            phrases << :send_application_uk_visa_renew_new
          end
          phrases << :"send_application_address_#{current_location}"
        else
          if %w(afghanistan burundi gaza).include?(current_location)
            phrases << :send_application_non_uk_visa_renew_new_colour
          else
            phrases << :send_application_non_uk_visa_renew_new
          end
          phrases << :send_application_embassy_address
        end
      else
        if passport_data['application_office']
          if %w(western-sahara).include?(current_location)
            phrases << :send_application_uk_visa_renew_old_replace_colour_western_sahara
          elsif uk_visa_application_with_colour_pictures.include?(current_location)
            phrases << :send_application_uk_visa_apply_renew_old_replace_colour
          else
            phrases << :send_application_uk_visa_apply_renew_old_replace
          end
          phrases << :"send_application_address_#{current_location}"
        else
          if %w(afghanistan burundi gaza).include?(current_location)
            phrases << :send_application_non_uk_visa_apply_renew_old_replace_colour
          else
            phrases << :send_application_non_uk_visa_apply_renew_old_replace
          end
          phrases << :send_application_embassy_address
        end
      end
    elsif %w(timor-leste).include?(current_location)
      phrases << :"send_application_#{current_location}" << :"send_application_address_#{current_location}"
    elsif %w(bangladesh india pakistan).include?(current_location)
      phrases << :"send_application_ips3_#{current_location}"
      phrases << :send_application_ips3_must_post unless %w(india bangladesh pakistan).include?(current_location)
      phrases << :send_application_ips3_must_post_colour_photo if %w(india pakistan).include?(current_location)
      phrases << :send_application_embassy_address
    elsif general_action == 'renewing' and data_query.renewing_countries?(current_location)
      if passport_data['application_office']
        phrases << :"send_application_address_#{current_location}"
      else
        if non_uk_visa_application_with_colour_pictures.include?(current_location)
          phrases << :send_application_non_uk_visa_renew_new_colour
        else
          phrases << :"send_application_ips#{ips_number}" << :renewing_new_renewing_old
        end
        phrases << :send_application_embassy_address
      end
    else
      if passport_data['application_office']
        phrases << :"send_application_address_#{current_location}"
      else
        if non_uk_visa_application_with_colour_pictures.include?(current_location)
          phrases << :send_application_non_uk_visa_apply_renew_old_replace_colour
        else
          phrases << :"send_application_ips#{ips_number}"
        end
        phrases << :send_application_embassy_address if ips_number.to_i > 1
      end
    end
    phrases
  end

  precalculate :getting_your_passport do
    collect_in_person_countries = %w(angola benin cameroon chad congo eritrea ethiopia gambia ghana guinea jamaica kenya nigeria somalia south-sudan zambia zimbabwe)
    collect_in_person_variant_countries = %w(burundi india jordan pitcairn-island)
    collect_in_person_renewing_new_variant_countries = %(burma nepal north-korea)
    uk_visa_application_centre_countries = %w(algeria azerbaijan china georgia indonesia kazakhstan lebanon mauritania morocco russia thailand ukraine venezuela western-sahara)
    uk_visa_application_centre_variant_countries = %w(cambodia egypt iraq libya rwanda sierra-leone tunisia uganda yemen)
    collect_with_photo_id_countries = %w(cambodia egypt iraq libya rwanda sierra-leone tunisia uganda yemen)
    passport_delivered_by_courier_countries = %w(laos)

    phrases = PhraseList.new
    if passport_delivered_by_courier_countries.include?(current_location)
      phrases << :passport_delivered_by_courier
    elsif uk_visa_application_centre_countries.include?(current_location)
      phrases << :getting_your_passport_uk_visa_centre
      if %w(renewing_new).include?(application_action)
        phrases << :getting_your_passport_contact << :getting_your_passport_id_renew_new
      else
        phrases << :getting_your_passport_contact_and_id
      end
    elsif uk_visa_application_centre_variant_countries.include?(current_location)
      phrases << :"getting_your_passport_#{current_location}" << :getting_your_passport_uk_visa_where_to_collect
      if %w(renewing_new).include?(application_action)
        if collect_with_photo_id_countries.include?(current_location)
          phrases << :getting_your_passport_with_id
        else
          phrases << :getting_your_passport_id_renew_new
        end
      else
        phrases << :getting_your_passport_id_apply_renew_old_replace
      end
    elsif collect_in_person_countries.include?(current_location)
      phrases << :"getting_your_passport_#{current_location}" << :getting_your_passport_contact_and_id
    elsif collect_in_person_variant_countries.include?(current_location)
      if %w(burundi).include?(current_location)
        if %w(renewing_new).include?(application_action)
          phrases << :"getting_your_passport_#{current_location}_renew_new"
        else
          phrases << :"getting_your_passport_#{current_location}" << :getting_your_passport_contact_and_id
        end
      else
        phrases << :"getting_your_passport_#{current_location}"
      end
    elsif collect_in_person_renewing_new_variant_countries.include?(current_location)
      phrases << :"getting_your_passport_#{current_location}" << :getting_your_passport_contact
      if %w(renewing_new).include?(application_action)
        phrases << :getting_your_passport_id_renew_new
      else
        phrases << :getting_your_passport_id_apply_renew_old_replace
      end
    else
      phrases << :"getting_your_passport_ips#{ips_number}"
    end
  end
  precalculate :contact_passport_adviceline do
    PhraseList.new(:contact_passport_adviceline)
  end
end

## FCO Result
outcome :fco_result do
  precalculate :how_long_it_takes do
    phrases = PhraseList.new
    phrases << :"how_long_#{waiting_time}"
    phrases << :you_may_have_to_attend_an_interview if %w(renewing_old applying).include?(application_action)
    phrases << :report_loss_or_theft if application_action == "replacing"
    phrases
  end

  precalculate :cost do
    cost_type = application_type
    payment_methods = :"passport_costs_#{application_type}"

    phrases = PhraseList.new(:"passport_courier_costs_#{cost_type}",
                             :"#{child_or_adult}_passport_costs_#{cost_type}",
                             payment_methods)

    phrases
  end

  precalculate :how_to_apply_supplement do
    if general_action == 'renewing' and data_query.retain_passport?(current_location)
      PhraseList.new(:how_to_apply_retain_passport)
    else
      ''
    end
  end

  precalculate :hurricane_warning do
    if general_action == 'renewing' and data_query.retain_passport_hurricanes?(current_location)
      PhraseList.new(:how_to_apply_retain_passport_hurricane)
    else
      ''
    end
  end

  precalculate :supporting_documents do
    if application_action == 'applying' and current_location == 'jordan'
      PhraseList.new(:supporting_documents_jordan_applying)
    elsif current_location == 'south-africa' and general_action == 'applying'
      PhraseList.new(:supporting_documents_south_africa_applying)
    else
      ''
    end
  end

  precalculate :send_your_application do
    phrases = PhraseList.new
    if %(south-africa).include?(current_location)
      phrases << :"send_application_#{current_location}"
    elsif current_location == 'indonesia'
      if application_action == 'applying' or application_action == 'replacing'
        phrases << :send_application_indonesia_applying
      else
        phrases << :send_application_fco_preamble << :"send_application_#{application_type}"
      end
    else
      phrases << :send_application_fco_preamble
      phrases << :"send_application_#{application_type}"
    end
    phrases
  end
  precalculate :getting_your_passport do
    location = 'fco'
    location = current_location if %(cambodia congo nepal).include?(current_location)
    PhraseList.new(:"getting_your_passport_#{location}")
  end
  precalculate :helpline do
    PhraseList.new(:"helpline_#{application_type}", :helpline_fco_webchat)
  end
end

## Generic country outcome.
outcome :result do
  precalculate :how_long_it_takes do
    PhraseList.new(:"how_long_#{application_type}")
  end
  precalculate :cost do
    PhraseList.new(:"cost_#{application_type}")
  end
  precalculate :how_to_apply do
    phrases = PhraseList.new(:"how_to_apply_#{application_type}")
    if general_action == 'renewing' and data_query.retain_passport?(current_location)
      phrases << :how_to_apply_retain_passport
    elsif general_action == 'renewing' and data_query.retain_passport_exception?(current_location)
      phrases << :how_to_apply_retain_passport_exception
    end
    phrases
  end
  precalculate :making_application_additional do
    if current_location == 'yemen'
      PhraseList.new(:making_application_additional_yemen)
    else
      ''
    end
  end
  precalculate :supporting_documents do
    phrase = ['supporting_documents', application_type]
    phrase << general_action if %w(iraq yemen zambia).include?(application_type)
    PhraseList.new(phrase.join('_').to_sym)
  end
  precalculate :making_application do
    PhraseList.new(:"making_application_#{application_type}")
  end
  precalculate :getting_your_passport do
    PhraseList.new(:"getting_your_passport_#{application_type}")
  end
  precalculate :helpline do
    phrases = PhraseList.new
    if %w(cuba libya morocco tunisia).include?(current_location)
      phrases << :helpline_exceptions
    elsif current_location == 'yemen'
      phrases << :helpline_exception_yemen
    else
      phrases << :helpline_intro << :"helpline_#{passport_data['helpline']}"
    end
    phrases << :helpline_fco_webchat
    phrases
  end
end

## No-op outcome.
outcome :cannot_apply do
  precalculate :organisation do
    location.fco_organisation
  end

  precalculate :overseas_passports_embassies do
    if organisation
      organisation.offices_with_service 'Overseas Passports Service'
    else
      []
    end
  end

  precalculate :body_text do
    PhraseList.new(:"body_#{current_location}")
  end
end

outcome :apply_in_neighbouring_country do
  precalculate :title_output do
    location.name
  end

  precalculate :emergency_travel_help do
    if %w(kyrgyzstan north-korea).include?(current_location)
      PhraseList.new(:"emergency_travel_help_#{current_location}")
    end
  end
end
