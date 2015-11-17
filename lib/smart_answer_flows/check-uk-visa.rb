module SmartAnswer
  class CheckUkVisaFlow < Flow
    def define
      content_id "dc1a1744-4089-43b3-b2e3-4e397b6b15b1"
      name 'check-uk-visa'
      status :published
      satisfies_need "100982"

      additional_countries = UkbaCountry.all

      # Q1
      country_select :what_passport_do_you_have?, additional_countries: additional_countries, exclude_countries: Calculators::UkVisaCalculator::EXCLUDE_COUNTRIES do
        next_node_calculation :calculator do
          Calculators::UkVisaCalculator.new
        end

        calculate :purpose_of_visit_answer do
          nil
        end

        permitted_next_nodes = [
          :israeli_document_type?,
          :outcome_no_visa_needed,
          :purpose_of_visit?
        ]
        next_node(permitted: permitted_next_nodes) do |response|
          calculator.passport_country = response
          if calculator.passport_country == 'israel'
            :israeli_document_type?
          elsif calculator.passport_country_in_eea?
            :outcome_no_visa_needed
          else
            :purpose_of_visit?
          end
        end
      end

      # Q1b
      multiple_choice :israeli_document_type? do
        option :"full-passport"
        option :"provisional-passport"

        permitted_next_nodes = [:purpose_of_visit?]
        next_node(permitted: permitted_next_nodes) do |response|
          calculator.passport_country = 'israel-provisional-passport' if response == 'provisional-passport'
          :purpose_of_visit?
        end
      end

      # Q2
      multiple_choice :purpose_of_visit? do
        option :tourism
        option :work
        option :study
        option :transit
        option :family
        option :marriage
        option :school
        option :medical
        option :diplomatic

        permitted_next_nodes = [
          :outcome_diplomatic_business,
          :outcome_joining_family_m,
          :outcome_joining_family_nvn,
          :outcome_joining_family_y,
          :outcome_marriage,
          :outcome_medical_n,
          :outcome_medical_y,
          :outcome_no_visa_needed,
          :outcome_school_n,
          :outcome_school_y,
          :outcome_standard_visit,
          :outcome_taiwan_exception,
          :outcome_visit_waiver,
          :passing_through_uk_border_control?,
          :staying_for_how_long?
        ]
        next_node(permitted: permitted_next_nodes) do |response|
          calculator.purpose_of_visit_answer = response

          if %w{study}.include?(calculator.purpose_of_visit_answer) || calculator.work_visit?
            next :staying_for_how_long?
          elsif calculator.purpose_of_visit_answer == 'diplomatic'
            next :outcome_diplomatic_business
          elsif %w{school medical}.include?(calculator.purpose_of_visit_answer) || calculator.tourism_visit?
            if %w(oman qatar united-arab-emirates).include?(calculator.passport_country)
              next :outcome_visit_waiver
            elsif calculator.passport_country == 'taiwan'
              next :outcome_taiwan_exception
            end
          end

          if calculator.passport_country_in_non_visa_national_list? || calculator.passport_country_in_ukot_list?
            if %w{school}.include?(calculator.purpose_of_visit_answer) || calculator.tourism_visit?
              next :outcome_school_n
            elsif calculator.purpose_of_visit_answer == 'medical'
              next :outcome_medical_n
            end
          end

          if calculator.purpose_of_visit_answer == 'school'
            :outcome_school_y
          elsif calculator.tourism_visit?
            :outcome_standard_visit
          elsif calculator.purpose_of_visit_answer == 'marriage'
            :outcome_marriage
          elsif calculator.purpose_of_visit_answer == 'medical'
            :outcome_medical_y
          elsif calculator.purpose_of_visit_answer == 'transit'
            if calculator.passport_country_in_datv_list? ||
                calculator.passport_country_in_visa_national_list? || %w(taiwan venezuela).include?(calculator.passport_country)
              :passing_through_uk_border_control?
            else
              :outcome_no_visa_needed
            end
          elsif calculator.purpose_of_visit_answer == 'family'
            if calculator.passport_country_in_ukot_list?
              :outcome_joining_family_m
            elsif calculator.passport_country_in_non_visa_national_list?
              :outcome_joining_family_nvn
            else
              :outcome_joining_family_y
            end
          end
        end
      end

      #Q3
      multiple_choice :passing_through_uk_border_control? do
        option :yes
        option :no

        permitted_next_nodes = [
          :outcome_no_visa_needed,
          :outcome_transit_leaving_airport,
          :outcome_transit_leaving_airport_datv,
          :outcome_transit_not_leaving_airport,
          :outcome_transit_refugee_not_leaving_airport,
          :outcome_visit_waiver
        ]
        next_node(permitted: permitted_next_nodes) do |response|
          calculator.passing_through_uk_border_control_answer = response

          next :outcome_visit_waiver if %w(taiwan).include?(calculator.passport_country)

          case calculator.passing_through_uk_border_control_answer
          when 'yes'
            if calculator.passport_country_in_visa_national_list?
              :outcome_transit_leaving_airport
            elsif calculator.passport_country_in_datv_list?
              :outcome_transit_leaving_airport_datv
            end
          when 'no'
            if %w(venezuela).include?(calculator.passport_country)
              :outcome_visit_waiver
            elsif calculator.passport_country == 'stateless-or-refugee'
              :outcome_transit_refugee_not_leaving_airport
            elsif calculator.passport_country_in_datv_list?
              :outcome_transit_not_leaving_airport
            elsif calculator.passport_country_in_visa_national_list?
              :outcome_no_visa_needed
            end
          end
        end
      end

      #Q4
      multiple_choice :staying_for_how_long? do
        option :six_months_or_less
        option :longer_than_six_months

        precalculate :study_or_work do
          if calculator.purpose_of_visit_answer == 'study'
            'study'
          elsif calculator.work_visit?
            'work'
          end
        end

        permitted_next_nodes = [
          :outcome_no_visa_needed,
          :outcome_study_m,
          :outcome_study_y,
          :outcome_taiwan_exception,
          :outcome_visit_waiver,
          :outcome_work_m,
          :outcome_work_n,
          :outcome_work_y
        ]
        next_node(permitted: permitted_next_nodes) do |response|
          case response
          when 'longer_than_six_months'
            if calculator.purpose_of_visit_answer == 'study'
              :outcome_study_y #outcome 2 study y
            elsif calculator.work_visit?
              :outcome_work_y #outcome 4 work y
            end
          when 'six_months_or_less'
            if calculator.purpose_of_visit_answer == 'study'
              if %w(oman qatar united-arab-emirates).include?(calculator.passport_country)
                :outcome_visit_waiver #outcome 12 visit outcome_visit_waiver
              elsif %w(taiwan).include?(calculator.passport_country)
                :outcome_taiwan_exception
              elsif calculator.passport_country_in_datv_list? || calculator.passport_country_in_visa_national_list?
                :outcome_study_m #outcome 3 study m visa needed short courses
              elsif calculator.passport_country_in_ukot_list? || calculator.passport_country_in_non_visa_national_list?
                :outcome_no_visa_needed #outcome 1 no visa needed
              end
            elsif calculator.work_visit?
              if calculator.passport_country_in_ukot_list? ||
                %w(taiwan).include?(calculator.passport_country) || calculator.passport_country_in_non_visa_national_list?
                #outcome 5.5 work N no visa needed
                :outcome_work_n
              elsif calculator.passport_country_in_datv_list? || calculator.passport_country_in_visa_national_list?
                # outcome 5 work m visa needed short courses
                :outcome_work_m
              end
            end
          end
        end
      end

      outcome :outcome_diplomatic_business
      outcome :outcome_joining_family_m
      outcome :outcome_joining_family_nvn
      outcome :outcome_joining_family_y
      outcome :outcome_marriage
      outcome :outcome_medical_n
      outcome :outcome_medical_y
      outcome :outcome_no_visa_needed
      outcome :outcome_school_n
      outcome :outcome_school_y
      outcome :outcome_standard_visit
      outcome :outcome_study_m
      outcome :outcome_study_y
      outcome :outcome_taiwan_exception
      outcome :outcome_transit_leaving_airport
      outcome :outcome_transit_leaving_airport_datv
      outcome :outcome_transit_not_leaving_airport
      outcome :outcome_transit_refugee_not_leaving_airport
      outcome :outcome_visit_waiver
      outcome :outcome_work_m
      outcome :outcome_work_n
      outcome :outcome_work_y
    end
  end
end
