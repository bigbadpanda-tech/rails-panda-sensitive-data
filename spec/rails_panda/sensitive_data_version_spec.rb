require "rails_helper"

RSpec.describe RailsPanda::SensitiveData do
  it "has a version number" do
    expect(RailsPanda::SensitiveData::VERSION).not_to be_nil
  end
end
