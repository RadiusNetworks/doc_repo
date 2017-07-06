require 'spec_helper'

RSpec.describe DocRepo do

  around do |ex|
    # Save and Reset the configuration
    original_config = DocRepo.configuration
    ex.run
    DocRepo.configuration = original_config
  end

  it "always has a configuration" do
    original_config = DocRepo.configuration
    expect {
      DocRepo.configuration = nil
    }.to change {
      DocRepo.configuration
    }.from(original_config).to an_instance_of(DocRepo::Configuration)
  end

  describe "modifying the configuration" do
    it "yields the configuration" do
      expect { |b|
        DocRepo.configure(&b)
      }.to yield_with_args DocRepo.configuration
    end

    it "reflects changes made by the block" do
      DocRepo.configuration.branch = "Any Branch"
      expect {
        DocRepo.configure do |c|
          c.branch = "Modified Branch"
        end
      }.to change {
        DocRepo.configuration.branch
      }.from("Any Branch").to "Modified Branch"
    end
  end

end
