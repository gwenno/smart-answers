status :published
satisfies_need "100220"

arrested_calc = SmartAnswer::Calculators::ArrestedAbroad.new
prisoner_packs = arrested_calc.data
exclude_countries = %w(holy-see british-antarctic-territory)

#Q1
country_select :which_country?, exclude_countries: exclude_countries do
  save_input_as :country

  calculate :location do
    loc = WorldLocation.find(country)
    raise InvalidResponse unless loc
    loc
  end

  calculate :organisation do
    location.fco_organisation
  end

  calculate :country_name do
    location.name
  end

  calculate :pdf do
    arrested_calc.generate_url_for_download(country, "pdf", "Prisoner pack for #{country_name}")
  end

  calculate :doc do
    arrested_calc.generate_url_for_download(country, "doc", "Prisoner pack for #{country_name}")
  end

  calculate :benefits do
    arrested_calc.generate_url_for_download(country, "benefits", "Benefits or legal aid in #{country_name}")
  end

  calculate :prison do
    arrested_calc.generate_url_for_download(country, "prison", "Information on prisons and prison procedures in #{country_name}")
  end

  calculate :judicial do
    arrested_calc.generate_url_for_download(country, "judicial", "Information on the judicial system and procedures in #{country_name}")
  end

  calculate :police do
    arrested_calc.generate_url_for_download(country, "police", "Information on the police and police procedures in #{country_name}")
  end

  calculate :consul do
    arrested_calc.generate_url_for_download(country, "consul", "Consul help available in #{country_name}")
  end

  calculate :lawyer do
    arrested_calc.generate_url_for_download(country, "lawyer", "English speaking lawyers and translators/interpreters in #{country_name}")
  end

  calculate :has_extra_downloads do
    [police, judicial, consul, prison, lawyer, benefits, doc, pdf].select { |x|
      x != ""
    }.length > 0 || arrested_calc.countries_with_regions.include?(country)
  end

  calculate :region_links do
    links = []
    if arrested_calc.countries_with_regions.include?(country)
      regions = arrested_calc.get_country_regions(country)
      regions.each do |key, val|
        links << "- [#{val['url_text']}](#{val['link']})"
      end
    end
    links
  end

  next_node_if(:answer_two_iran, responded_with('iran'))
  next_node_if(:answer_three_syria, responded_with('syria'))
  next_node(:answer_one_generic)
end

outcome :answer_one_generic do
  precalculate :intro do
    PhraseList.new(:common_intro)
  end

  precalculate :generic_downloads do
    transfers_back_to_uk_treaty_change_countries = %(austria belgium croatia denmark finland hungary italy latvia luxembourg malta netherlands slovakia)

    phrases = PhraseList.new
    phrases << :common_downloads
    if transfers_back_to_uk_treaty_change_countries.exclude?(country)
      phrases << :transfers_back_to_the_uk_download
    end
    phrases
  end

  precalculate :country_downloads do
    has_extra_downloads ? PhraseList.new(:specific_downloads) : PhraseList.new
  end

  precalculate :region_downloads do
    region_links.join("\n")
  end

  precalculate :after_downloads do
    PhraseList.new(:fco_cant_do, :dual_nationals_other_help, :further_links)
  end

end

outcome :answer_two_iran do
  precalculate :downloads do
    PhraseList.new(:common_downloads)
  end

  precalculate :further_help_links do
    PhraseList.new(:further_links)
  end
end

outcome :answer_three_syria do
  precalculate :downloads do
    PhraseList.new(:common_downloads)
  end

  precalculate :further_help_links do
    PhraseList.new(:further_links)
  end
end
