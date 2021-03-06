module Interventions
  module Phytosanitary
    class ProductStateValidator < ProductApplicationValidator

      # @param [Array<Models::ProductWithUsage>] products_usages
      # @return [Models::ProductApplicationResult]
      def validate(products_usages)
        result = Models::ProductApplicationResult.new

        products_usages.each do |pu|
          if pu.phyto.nil? || pu.usage.nil?
            result.vote_unknown(pu.product)
          elsif pu.phyto.withdrawn? || pu.usage.withdrawn?
            result.vote_forbidden(pu.product, :this_product_has_been_withdrawn.tl)
          end
        end

        result
      end
    end
  end
end
