# encoding: UTF-8
require_relative '../../test_helper'
require_relative 'flow_test_helper'
require 'gds_api/test_helpers/worldwide'

class RegisterADeathTest < ActiveSupport::TestCase
  include FlowTestHelper
  include GdsApi::TestHelpers::Worldwide

  setup do
    @location_slugs = %w(afghanistan andorra argentina australia austria barbados belgium brazil china dominica egypt france germany hong-kong indonesia iran italy libya malaysia morocco netherlands slovakia spain st-kitts-and-nevis sweden taiwan usa)
    worldwide_api_has_locations(@location_slugs)
    setup_for_testing_flow 'register-a-death'
  end

  should "ask where the death happened" do
    assert_current_node :where_did_the_death_happen?
  end

  context "answer England or Wales" do
    setup do
      add_response 'england_wales'
    end
    should "ask whether the death occurred at home or in hospital or elsewhere" do
      assert_current_node :did_the_person_die_at_home_hospital?
    end
    context "answer home or in hospital" do
      setup do
        add_response 'at_home_hospital'
      end
      should "ask if the death was expected" do
        assert_current_node :was_death_expected?
      end
      should "be outcome1 if death was expected" do
        add_response 'yes'
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_ew,
          :who_can_register, :who_can_register_home_hospital,
          :what_you_need_to_do_expected, :need_to_tell_registrar,
          :documents_youll_get_ew_expected]
      end
      should "be outcome3 if death not expected" do
        add_response 'no'
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_ew,
          :who_can_register, :who_can_register_home_hospital,
          :what_you_need_to_do_unexpected, :need_to_tell_registrar,
          :documents_youll_get_ew_unexpected]
      end
    end
    context "answer elsewhere" do
      setup do
        add_response 'elsewhere'
      end
      should "ask if the death was expected" do
        assert_current_node :was_death_expected?
      end
      should "be outcome2 if death was expected" do
        add_response :yes
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_ew,
          :who_can_register, :who_can_register_elsewhere,
          :what_you_need_to_do_expected, :need_to_tell_registrar,
          :documents_youll_get_ew_expected]
      end

      should "be outcome4 if death not expected" do
        add_response :no
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_ew,
          :who_can_register, :who_can_register_elsewhere,
          :what_you_need_to_do_unexpected, :need_to_tell_registrar,
          :documents_youll_get_ew_unexpected]
      end
    end
  end # England, Wales

  context "answer Scotland" do
    setup do
      add_response 'scotland'
    end
    should "ask whether the death occurred at home, in hospital or elsewhere" do
      assert_current_node :did_the_person_die_at_home_hospital?
    end
    context "answer home or in hospital" do
      setup do
        add_response 'at_home_hospital'
      end
      should "ask if the death was expected" do
        assert_current_node :was_death_expected?
      end
      should "be outcome5 if death was expected" do
        add_response :yes
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_scotland]
      end
      should "be outcome7 if death not expected" do
        add_response :no
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_scotland]
      end
    end
    context "answer elsewhere" do
      setup do
        add_response 'elsewhere'
      end
      should "ask if the death was expected" do
        assert_current_node :was_death_expected?
      end
      should "be outcome6 if death was expected" do
        add_response :yes
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_scotland]
      end

      should "be outcome8 if death not expected" do
        add_response :no
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_scotland]
      end
    end
  end # Scotland

  context "answer Northern Ireland" do
    setup do
      add_response 'northern_ireland'
    end
    should "ask whether the death occurred at home, in hospital or elsewhere" do
      assert_current_node :did_the_person_die_at_home_hospital?
    end
    context "answer home or in hospital" do
      setup do
        add_response 'at_home_hospital'
      end
      should "ask if the death was expected" do
        assert_current_node :was_death_expected?
      end
      should "be outcome5 if death was expected" do
        add_response :yes
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_northern_ireland]
      end
      should "be outcome7 if death not expected" do
        add_response :no
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_northern_ireland]
      end
    end
    context "answer elsewhere" do
      setup do
        add_response 'elsewhere'
      end
      should "ask if the death was expected" do
        assert_current_node :was_death_expected?
      end
      should "be outcome6 if death was expected" do
        add_response :yes
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_northern_ireland]
      end

      should "be outcome8 if death not expected" do
        add_response :no
        assert_current_node :uk_result
        assert_phrase_list :content_sections, [:intro_northern_ireland]
      end
    end
  end # Northern Ireland

  context "answer overseas" do
    setup do
      add_response 'overseas'
    end

    should "ask which country" do
      assert_current_node :which_country?
    end
    context "answer Australia" do
      setup do
        add_response 'australia'
      end
      should "give the commonwealth result" do
        assert_state_variable :current_location_name, "Australia"
        assert_current_node :commonwealth_result
      end
    end # Australia (commonwealth country)
    context "answer Spain" do
      setup do
        worldwide_api_has_organisations_for_location('spain', read_fixture_file('worldwide/spain_organisations.json'))
        add_response 'spain'
      end
      should "ask where you are now" do
        assert_state_variable :current_location_name, "Spain"
        assert_current_node :where_are_you_now?
      end
      context "answer same country" do
        setup do
          add_response 'same_country'
        end
        should "give the embassy result and be done" do
          assert_current_node :oru_result
          assert_phrase_list :oru_address, [:oru_address_abroad]
          assert_phrase_list :translator_link, [:approved_translator_link]
          assert_state_variable :translator_link_url, "/government/publications/spain-list-of-lawyers"
        end
      end # Answer embassy
      context "answer ORU office in the uk" do
        setup do
          add_response 'in_the_uk'
        end
        should "give the ORU result and be done" do
          assert_current_node :oru_result
          assert_phrase_list :oru_address, [:oru_address_uk]
          assert_phrase_list :translator_link, [:approved_translator_link]
          assert_state_variable :translator_link_url, "/government/publications/spain-list-of-lawyers"
        end
      end # Answer ORU
    end # Answer Spain

    context "answer Morocco" do
      setup do
        worldwide_api_has_organisations_for_location('morocco', read_fixture_file('worldwide/morocco_organisations.json'))
        add_response 'morocco'
      end
      should "ask where are you now" do
        assert_state_variable :current_location_name, "Morocco"
        assert_current_node :where_are_you_now?
      end
      context "answer ORU office in the uk" do
        setup do
          add_response 'in_the_uk'
        end
        should "give the ORU result and be done" do
          assert_current_node :oru_result
          assert_phrase_list :translator_link, [:no_translator_link]
          assert_state_variable :translator_link_url, nil
        end
      end # Answer ORU
    end # Morocco

    context "answer Argentina" do
      setup do
        worldwide_api_has_organisations_for_location('argentina', read_fixture_file('worldwide/argentina_organisations.json'))
        add_response 'argentina'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_phrase_list :clickbook, [:clickbook]
        expected_location = WorldLocation.find('argentina')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Argentina
    context "answer China" do
      setup do
        worldwide_api_has_organisations_for_location('china', read_fixture_file('worldwide/china_organisations.json'))
        add_response 'china'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy or consulate"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_phrase_list :clickbook, [:clickbooks]
        assert_state_variable :death_country_name_lowercase_prefix, 'China'
        assert outcome_body.at_css("ul li a[href='https://www.clickbook.net/dev/bc.nsf/sub/BritEmBeijing']")
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        expected_location = WorldLocation.find('china')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer China
    context "answer Austria" do
      setup do
        worldwide_api_has_organisations_for_location('austria', read_fixture_file('worldwide/austria_organisations.json'))
        add_response 'austria'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
        assert_state_variable :clickbook, ''
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, "/government/publications/passport-credit-debit-card-payment-authorisation-slip-austria"
        assert_phrase_list :postal, [:postal_intro, :postal_registration_by_form]
        expected_location = WorldLocation.find('austria')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Austria
    context "answer Slovakia" do
      setup do
        worldwide_api_has_organisations_for_location('slovakia', read_fixture_file('worldwide/slovakia_organisations.json'))
        add_response 'slovakia'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, "/government/publications/credit-card-authorisation-form--2"
        assert_phrase_list :postal, [:post_only_pay_by_card_countries]
      end
    end # Answer Slovakia
    context "answer Italy" do
      setup do
        worldwide_api_has_organisations_for_location('italy', read_fixture_file('worldwide/italy_organisations.json'))
        add_response 'italy'
        add_response 'same_country'
      end
      should "give the ORU result and be done" do
        assert_current_node :oru_result
        assert_phrase_list :oru_address, [:oru_address_abroad]
        assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        assert_phrase_list :translator_link, [:approved_translator_link]
        assert_state_variable :translator_link_url, "/government/publications/italy-list-of-lawyers"
      end
    end # Answer Italy
    context "death occurred in Andorra" do
      setup do
        worldwide_api_has_organisations_for_location('spain', read_fixture_file('worldwide/spain_organisations.json'))
        add_response 'andorra'
        add_response 'same_country'
      end
      should "give the oru result and be done" do
        assert_current_node :oru_result
        assert_phrase_list :oru_address, [:oru_address_abroad]
        assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        assert_phrase_list :translator_link, [:approved_translator_link]
        assert_state_variable :translator_link_url, "/government/publications/spain-list-of-lawyers"
      end
    end # Answer Andorra
    context "death occurred in Andorra, but they are now in France" do
      setup do
        worldwide_api_has_organisations_for_location('france', read_fixture_file('worldwide/france_organisations.json'))
        add_response 'andorra'
        add_response 'another_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :oru_result
        assert_phrase_list :oru_address, [:oru_address_abroad]
        assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        assert_phrase_list :translator_link, [:approved_translator_link]
        assert_state_variable :translator_link_url, "/government/publications/spain-list-of-lawyers"
      end
    end # Answer Andorra, now in France
    context "answer Afghanistan" do
      setup do
        worldwide_api_has_organisations_for_location('afghanistan', read_fixture_file('worldwide/afghanistan_organisations.json'))
        add_response 'afghanistan'
      end
      context "currently still in the country" do
        should "give the embassy result and be done" do
          add_response 'same_country'
          assert_current_node :embassy_result
          assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
          assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
          assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
          assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
          assert_phrase_list :footnote, [:footnote_exceptions]
          expected_location = WorldLocation.find('afghanistan')
          assert_state_variable :location, expected_location
          assert_state_variable :organisation, expected_location.fco_organisation
        end
      end
      context "now back in the UK" do
        should "give the ORU result and be done" do
          add_response 'in_the_uk'
          assert_current_node :oru_result
          assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
          assert_phrase_list :oru_address, [:oru_address_uk]
          assert_phrase_list :translator_link, [:no_translator_link]
          assert_state_variable :translator_link_url, nil
        end
      end
    end # Answer Afghanistan
    context "answer Iran" do
      setup do
        worldwide_api_has_organisations_for_location('iran', read_fixture_file('worldwide/iran_organisations.json'))
        add_response 'iran'
      end
      should "give the no embassy result" do
        add_response :no_embassy_result
        expected_location = WorldLocation.find('iran')
      end
    end # Iran
    context "answer Libya" do
      setup do
        worldwide_api_has_organisations_for_location('libya', read_fixture_file('worldwide/libya_organisations.json'))
        add_response 'libya'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy_libya]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees_libya]
        assert_state_variable :postal_form_url, nil
        expected_location = WorldLocation.find('libya')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Libya
    context "answer Sweden" do
      setup do
        worldwide_api_has_organisations_for_location('sweden', read_fixture_file('worldwide/sweden_organisations.json'))
        add_response 'sweden'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy_sweden]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_phrase_list :clickbook, [:clickbook]
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, nil
        assert_phrase_list :postal, [:postal_intro, :postal_registration_sweden]
        expected_location = WorldLocation.find('sweden')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Sweden
    context "answer Hong Kong" do
      setup do
        worldwide_api_has_organisations_for_location('hong-kong', read_fixture_file('worldwide/hong-kong_organisations.json'))
        add_response 'hong-kong'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British consulate general"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy_hong_kong]
        assert_state_variable :clickbook, ''
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, nil
        expected_location = WorldLocation.find('hong-kong')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Hong Kong
    context "answer Brazil" do
      setup do
        worldwide_api_has_organisations_for_location('brazil', read_fixture_file('worldwide/brazil_organisations.json'))
        add_response 'brazil'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British consulate general"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_phrase_list :clickbook, [:clickbook]
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, "/government/publications/credit-card-authorization-form"
        assert_phrase_list :postal, [:postal_intro, :postal_registration_by_form]
        expected_location = WorldLocation.find('brazil')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Brazil
    context "answer Germany" do
      setup do
        worldwide_api_has_organisations_for_location('germany', read_fixture_file('worldwide/germany_organisations.json'))
        add_response 'germany'
        add_response 'same_country'
      end
      should "give the ORU result and be done" do
        assert_current_node :oru_result
        assert_phrase_list :oru_address, [:oru_address_abroad]
        assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        assert_phrase_list :translator_link, [:approved_translator_link]
        assert_state_variable :translator_link_url, "/government/publications/germany-list-of-lawyers"
      end
    end # Answer Germany
    context "answer USA" do
      setup do
        worldwide_api_has_organisations_for_location('usa', read_fixture_file('worldwide/usa_organisations.json'))
        add_response 'usa'
        add_response 'same_country'
      end
      should "give the oru result and be done" do
        assert_current_node :oru_result
        assert_phrase_list :oru_address, [:oru_address_abroad]
        assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        assert_phrase_list :translator_link, [:no_translator_link]
        assert_state_variable :translator_link_url, nil
      end
    end # Answer USA
    context "answer Netherlands" do
      setup do
        worldwide_api_has_organisations_for_location('netherlands', read_fixture_file('worldwide/netherlands_organisations.json'))
        add_response 'netherlands'
        add_response 'same_country'
      end
      should "give the ORU result and be done" do
        assert_current_node :oru_result
        assert_phrase_list :oru_address, [:oru_address_abroad]
        assert_state_variable :button_data, {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        assert_phrase_list :translator_link, [:approved_translator_link]
        assert_state_variable :translator_link_url, "/government/publications/netherlands-list-of-lawyers"
      end
    end # Answer Netherlands
    context "answer death in dominica, user in st kitts" do
      setup do
        worldwide_api_has_organisations_for_location('barbados', read_fixture_file('worldwide/barbados_organisations.json'))
        add_response 'dominica'
        add_response 'another_country'
        add_response 'st-kitts-and-nevis'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British high commission"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_state_variable :clickbook, ''
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, nil
        assert_state_variable :cash_only, ''
        assert_phrase_list :footnote, [:footnote_caribbean]
        expected_location = WorldLocation.find('barbados')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Dominica
    context "answer death in malaysia, user in same country" do
      setup do
        worldwide_api_has_organisations_for_location('malaysia', read_fixture_file('worldwide/malaysia_organisations.json'))
        add_response 'malaysia'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy_malaysia]
        assert_state_variable :embassy_high_commission_or_consulate, "British high commission"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_state_variable :clickbook, ''
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, nil
        assert_state_variable :cash_only, ''
        assert_phrase_list :footnote, [:footnote]
        expected_location = WorldLocation.find('malaysia')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Malaysia
    context "answer death in indonesia, user in same country" do
      setup do
        worldwide_api_has_organisations_for_location('indonesia', read_fixture_file('worldwide/indonesia_organisations.json'))
        add_response 'indonesia'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British embassy"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_state_variable :clickbook, ''
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, nil
        assert_state_variable :cash_only, ''
        assert_phrase_list :footnote, [:footnote]
        assert_match /British Embassy Jakarta/, outcome_body
        expected_location = WorldLocation.find('indonesia')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Taiwan
    context "answer death in taiwan, user in same country" do
      setup do
        worldwide_api_has_organisations_for_location('taiwan', read_fixture_file('worldwide/taiwan_organisations.json'))
        add_response 'taiwan'
        add_response 'same_country'
      end
      should "give the embassy result and be done" do
        assert_current_node :embassy_result
        assert_phrase_list :documents_required_embassy_result, [:documents_list_embassy]
        assert_state_variable :embassy_high_commission_or_consulate, "British Trade & Cultural Office"
        assert_phrase_list :booking_text_embassy_result, [:booking_text_embassy]
        assert_state_variable :clickbook, ''
        assert_phrase_list :fees_for_consular_services, [:consular_service_fees]
        assert_state_variable :postal_form_url, nil
        assert_phrase_list :cash_only, [:cheque_only]
        assert_phrase_list :footnote, [:footnote_exceptions]
        expected_location = WorldLocation.find('taiwan')
        assert_state_variable :location, expected_location
        assert_state_variable :organisation, expected_location.fco_organisation
      end
    end # Answer Taiwan

    context "answer death in Egypt, user in Belgium" do
      setup do
        worldwide_api_has_organisations_for_location('belgium', read_fixture_file('worldwide/belgium_organisations.json'))
        add_response 'egypt'
        add_response 'another_country'
        add_response 'belgium'
      end
      should "give embassy_result" do
        assert_current_node :embassy_result
        assert_state_variable :death_country_name_lowercase_prefix, 'Egypt'
        assert_state_variable :current_location_name_lowercase_prefix, 'Belgium'
        assert_state_variable :current_location, 'belgium'
      end
    end # Death in Egypt user in Belgium
  end # Overseas
end
