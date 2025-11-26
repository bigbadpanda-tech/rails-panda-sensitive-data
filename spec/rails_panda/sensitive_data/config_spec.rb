require "rails_helper"

RSpec.describe RailsPanda::SensitiveData::Config do
  describe ".config" do
    it "returns a Config instance" do
      expect(RailsPanda::SensitiveData.config).to be_a(described_class)
    end

    it "memoizes the config" do
      config1 = RailsPanda::SensitiveData.config
      config2 = RailsPanda::SensitiveData.config

      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the config" do
      expect { |b| RailsPanda::SensitiveData.configure(&b) }.to yield_with_args(described_class)
    end

    it "allows configuration" do
      RailsPanda::SensitiveData.configure do |config|
        expect(config).to be_a(described_class)
      end
    end
  end
end
