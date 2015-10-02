require 'spec_helper'

describe Litmus::Instant do
  it 'has a version number' do
    expect(Litmus::Instant::VERSION).not_to be nil
  end

  describe 'module methods' do
    it 'has an api_key setter' do
      expect {
        Litmus::Instant.api_key = "foo"
      }.not_to raise_error
    end
  end
end
