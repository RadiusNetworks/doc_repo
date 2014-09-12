module DocRepo
  class Configuration
    attr_accessor :org, :repo, :branch

    def initialize
      @branch = "master"
    end
  end
end
