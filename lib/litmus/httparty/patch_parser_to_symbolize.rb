module HTTParty
  class Parser
    protected
    def json
      result = Crack::JSON.parse(body)
      case result
      when Array
        result.map { |child| child.is_a?(Hash) ? child.deep_symbolize_keys : child }
      when Hash
        result.deep_symbolize_keys
      else
        result
      end
    end
  end
end
