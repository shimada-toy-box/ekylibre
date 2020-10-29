json.array! elements do |phytosanitary_product|
  json.call(phytosanitary_product, :id,
            :reference_name,
            :name,
            :other_names,
            :natures,
            :active_compounds,
            :france_maaid,
            :mix_category_codes,
            :in_field_reentry_delay,
            :state,
            :started_on,
            :stopped_on,
            :allowed_mentions,
            :restricted_mentions,
            :operator_protection_mentions,
            :firm_name,
            :product_type,
            :record_checksum)
end