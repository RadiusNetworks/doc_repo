module DocRepo
  class Configuration
    attr_accessor :org, :repo, :branch

    def initialize
      @org = "RadiusNetworks"
      @branch = "master"
    end
  end
end
