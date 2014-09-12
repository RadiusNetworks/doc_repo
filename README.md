# DocRepo

Store your markdown based documentation in a repo but serve it from with in your app.

This is a little project that will pull raw markdown from the GitHub API and proxy them through your app. This lets you render things in your app, customize the layout and access control -- but lets you update the docs without re-deploying.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'doc_repo'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install doc_repo

## Usage

Create an initializer to configure Doc Repo, in rails this would live in `config/initializers/doc_repo.rb`:

```ruby
DocRepo.configure do |c|
  # GitHub Orgnization or User:
  c.org = "RadiusNetworks"

  # GitHub Repo:
  c.repo = "proximitykit-documentation"

  # Git Branch (Optional):
  c.branch = "master"
end
```

Create a controller to render the documentation pages. In Rails you might use something like this:

```ruby
class DocsController < ApplicationController
  def index
    # If you don't want to store the index view in the app, just redirect to
    # one of the documentation pages:
    redirect_to doc_path('index')
  end

  def show
    DocRepo.respond_with(params[:slug]) do |f|
      # Render the body:
      f.html {|body| render text: body, layout: "docs" }

      # Redirect to images and assets:
      f.redirect {|url| redirect_to url }
    end
  rescue DocRepo::NotFound
    raise ActionController::RoutingError.new('Not Found')
  end

end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License.  See the [LICENSE file](LICENSE.txt) for details.
