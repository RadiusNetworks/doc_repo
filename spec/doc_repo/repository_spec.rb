require 'spec_helper'

RSpec.describe DocRepo::Repository do

  it "yields the file block for a jpg" do
    repo = DocRepo::Repository.new

    repo.respond("sonic_screwdriver.png") do |r|
      expect { |b| r.redirect(&b) }.to yield_control
      expect { |b| r.html(&b) }.not_to yield_control
    end
  end

  it "determines the right mime type for a jpg" do
    repo = DocRepo::Repository.new

    repo.respond("sonic_screwdriver.png") do |r|
      r.redirect do |url|
        expect( url ).to match %r{https://raw\..*/master/docs/sonic_screwdriver.png}
      end
    end
  end

end

