module Accountancy
  class AccountNumberNormalizer
    class NormalizationError < StandardError
    end

    DEFAULT_CENTRALIZED_PREFIXES = %w(401 411).freeze

    class << self
      def build
        new(
          Preference[:account_number_digits],
          centralized_accounts_prefixes: DEFAULT_CENTRALIZED_PREFIXES
        )
      end
    end

    attr_reader :standard_length, :centralized_accounts_prefixes

    # @param [Integer] standard_length
    # @param [Array<String>] centralized_accounts_prefixes
    def initialize(standard_length, centralized_accounts_prefixes:)
      @standard_length = standard_length
      @centralized_accounts_prefixes = centralized_accounts_prefixes
    end

    # @param [String|Symbol|Number] number
    # @return [String]
    def normalize!(number)
      number = number.to_s

      if centralized?(number) || number.size == standard_length
        number
      elsif number.size > standard_length
        truncate(number)
      else
        number.ljust(standard_length, "0")
      end
    end

    # @param [String] number
    # @return boolean
    def centralized?(number)
      centralized_accounts_prefixes.any? { |p| number.start_with?(p) }
    end

    # @param [String] number
    # @raise [NormalizationError]
    # @return [String]
    def truncate(number)
      removed = number[standard_length..-1]
      if all_zero?(removed)
        number[0...standard_length]
      else
        raise NormalizationError
      end
    end

    # @param [String] string
    # @return [Boolean]
    def all_zero?(string)
      string.match(/\A0+\z/).present?
    end
  end
end