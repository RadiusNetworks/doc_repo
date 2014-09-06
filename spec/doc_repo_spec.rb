require 'spec_helper'

RSpec.describe DocRepo do

  around do |ex|
    # Save and Reset the configuration
    original_config = DocRepo.configuration
    ex.run
    DocRepo.instance_variable_set :@configuration, original_config
  end

  it "yields the configuration" do
      expect { |b|
        DocRepo.configure(&b)
      }.to yield_control
  end

end
