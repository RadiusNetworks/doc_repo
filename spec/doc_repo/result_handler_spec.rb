# frozen_string_literal: true

RSpec.describe DocRepo::ResultHandler do

  shared_examples "handling results of type" do |type|
    subject(:a_handler) { DocRepo::ResultHandler.new }

    it "requires a block" do
      expect {
        a_handler.public_send type
      }.to raise_error ArgumentError, "Result handler block required"
    end

    it "does not evaluate the block when defined" do
      expect { |b| a_handler.public_send type, &b }.not_to yield_control
    end

    it "stores the block" do
      handler_strategy = -> { "Does Anything" }
      expect {
        a_handler.public_send type, &handler_strategy
      }.to change {
        a_handler[type.to_sym]
      }.from(nil).to(handler_strategy)
    end
  end

  it "has no actions by default" do
    expect(DocRepo::ResultHandler.new.each.to_a).to be_empty
  end

  include_behavior "handling results of type", :complete
  include_behavior "handling results of type", :error
  include_behavior "handling results of type", :not_found
  include_behavior "handling results of type", :redirect

end
