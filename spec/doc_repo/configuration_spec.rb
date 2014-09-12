require 'support/using_env'

RSpec.describe DocRepo::Configuration do

  context "without environment variables configured" do
    subject(:default_config) { DocRepo::Configuration.new }

    around do |example|
      env = {
        'DOC_REPO_ORG'      => nil,
        'DOC_REPO_REPONAME' => nil,
        'DOC_REPO_BRANCH'   => nil,
      }
      using_env(env, &example)
    end

    it "has no org" do
      expect(default_config.org).to be nil
    end

    it "has no repo" do
      expect(default_config.repo).to be nil
    end

    it "use the 'master' branch" do
      expect(default_config.branch).to eq 'master'
    end
  end

  context "with environment variables configured" do
    subject(:default_env_config) { DocRepo::Configuration.new }

    around do |example|
      env = {
        'DOC_REPO_ORG'      => 'the-silence',
        'DOC_REPO_REPONAME' => 'falls',
        'DOC_REPO_BRANCH'   => 'ask_the_question',
      }
      using_env(env, &example)
    end

    it "uses DOC_REPO_ORG for the default org" do
      expect(default_env_config.org).to eq 'the-silence'
    end

    it "uses DOC_REPO_REPONAME for the default repo" do
      expect(default_env_config.repo).to eq 'falls'
    end

    it "uses DOC_REPO_BRANCH for the default branch" do
      expect(default_env_config.branch).to eq 'ask_the_question'
    end
  end

end
