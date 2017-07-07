# DocRepo

Store your markdown based documentation in a repo but serve it from with in
your app.

This is a little project that will pull raw markdown from the GitHub API and
proxy them through your app. This lets you render things in your app, customize
the layout and access control -- but lets you update the docs without
re-deploying.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'doc_repo'
```

And then execute:

```console
$ bundle
```

Or install it yourself as:

```console
$ gem install doc_repo
```

## Usage

Initialize the configuration through `DocRepo.configuration`. It's good to
place this somewhere early in the app startup (such as a Rails initializer
`config/initializers/doc_repo.rb`):

```ruby
DocRepo.configure do |c|
  # GitHub Organization or User:
  c.org = "RadiusNetworks"

  # GitHub Repo:
  c.repo = "doc_repo"

  # Git Branch (Optional - default is 'master'):
  c.branch = "master"
end
```

Requests for documents can then be made through `DocRepo.request`:

```ruby
DocRepo.request(params[:slug]) do |on|
  on.complete do |doc|
    # Do something with the document
  end

  on.redirect do |target|
    # The asset exists else where and should be requested directly
  end
end
```

### Advanced Configuration

Most functionality in Doc Repo can be configured. The full list of available
settings is:

```ruby
DocRepo.configure do |c|
  # Repo settings
  c.org = "YourOrg"
  c.repo = "your_repo"
  c.branch = "api-v2"               # Default: "master"
  c.doc_root = "/api-docs/rest"     # Default: "docs"

  # Content settings
  c.doc_formats = %w[               # Default: %w[ .md .markdown .htm .html ]
    .md
    .mark
    .txt
  ]
  c.fallback_ext = ".mark"          # Default: ".md"

  # Cache settings
  c.cache_store = Rails.cache       # Default: DocRepo::NullCache.instance
  c.cache_options = {               # Default: {}
    namespace: :docs,
    expires_in: 36.hours,
  }
end
```

When a request is made for a URI with an extension not listed in `doc_formats`
the `redirect` handler will be called without making a remote request.

### Error Handling

When no error handling is configured errors are raised:

```ruby
def show
  DocRepo.request(params[:slug]) do |on|
    on.complete do |doc|
      # Do something with the document
    end

    on.redirect do |target|
      # The asset exists else where and should be requested directly
    end
  end
rescue DocRepo::Error => error
  # Handle the error
end
```

However, errors such as a missing document may be more common and behavior
handling should be treated differently. An example of this is a Rails app which
pulls the document name from the URL. When someone mistypes the URL that isn't
really an internal error.

Doc Repo provides an alternative interface to avoid control flow by exception.
This interface also allows separating behavior for the common missing document
from other error cases:

```ruby
DocRepo.request(params[:slug]) do |on|
  on.complete do |doc|
    # Do something with the document
  end

  on.redirect do |target|
    # The asset exists else where and should be requested directly
  end

  on.not_found do |error|
    # Handle the missing document
  end

  on.error do |error|
    # Handle the error
  end
end
```

When the `not_found` handler is left undefined the defined `error` handler will
be called. When this is not defined the default `raise` behavior is used.

### Caching

By default no caching is enabled. Specifically the default configuration uses a
null cache which results in all requests being sent to the remote origin
server. Custom cache stores can configured through the `cache_store`
configuration setting. In order for Doc Repo to work with the custom cache it
must implement the following APIs (existing Rails cache stores implement
these):

  - `fetch(key, options = {}, &block)`
  - `write(key, value, options = {})`

Any configured `cache_options` are provided directly to the `cache_store` for
all `fetch` and `write` calls.

When a custom cache store is configured it will be used as an internal local
HTTP cache. This HTTP cache will prevent remote origin requests when possible.
This is accomplished by serving content from local cache as long as the cache
is valid per the cache store. Additionally, Doc Repo supports a basic
understanding of general HTTP cache through the
[`Expires`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expires)([RFC
7234](https://tools.ietf.org/html/rfc7234#section-5.3)) header.

When a local HTTP cache has expired according to the `Expires` header, but is
still valid in `cache_store`, a conditional `GET` request will be made to the
origin server. Any [`ETag`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)([RFC
7232](https://tools.ietf.org/html/rfc7232#section-2.3)) or
[`Last-Modified`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified)([RFC
7232](https://tools.ietf.org/html/rfc7232#section-2.2)) headers originally
provided by the origin server will be sent in the request through
[`If-None-Match`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-None-Match)([RFC
7232](https://tools.ietf.org/html/rfc7232#section-3.2)) and
[`If-Modified-Since`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Modified-Since)([RFC
7232](https://tools.ietf.org/html/rfc7232#section-3.3)) headers respectively.

Based on the response either the existing cache will be refreshed (i.e. in
response to a `304 Not Modified`) or replaced (i.e. in response to a `200 OK`).
This will cause the local HTTP cache to be re-written to the `cache_store`.

### Rails

We suggest creating a controller to render the documentation pages. A simple
implementation may look like the following:

```ruby
class DocsController < ApplicationController
  def index
    # If you don't want to store the index view in the app, just redirect to
    # one of the documentation pages:
    redirect_to doc_path('index')
  end

  def show
    DocRepo.request(params[:slug]) do |on|
      on.complete do |target|
        @doc = doc
        fresh_when @doc
      end

      on.redirect do |target|
        redirect_to target.location, status: target.code
      end

      on.not_found do |error|
        logger.warn "Not Found (URI=#{error.uri})"
        render file: "public/404.html", status: :not_found, layout: false
      end
    end
  end
end
```

#### Rendering and Views

By default all `DocRepo::Doc` instances will generate safe HTML when provided
to `render` as the following types `:html`, `:plain`, and `:body`:

```ruby
DocRepo.request(params[:slug]) do |on|
  on.complete do |doc|
    # These two lines are equivalent
    render html: doc.to_html.html_safe
    render html: doc

    # As are these
    render plain: doc.to_html.html_safe
    render plain: doc
  end
end
```

For those documents which are written in markdown, if you wish to provide a way
to display the raw markdown you will need to explicitly provide it through
`DocRepo::Doc#content`:

```ruby
DocRepo.request(params[:slug]) do |on|
  on.complete do |doc|
    respond_to do |format|
      format.html { render html: doc }

      format.text { render plain: doc.content }
    end
  end
end
```

Inside of a view you will need to call `to_html`, `content` or `to_text` as
appropriate:

```erb
<%== doc.to_html %>
```

```erb
<%= doc.to_html.html_safe %>
```

#### View Caches and Conditional `GET` Support

The above mentioned caching behavior does not hook into the Rails view cache
nor the conditional `GET` request/response interfaces. However, `DocRepo::Doc`
instances provided to the `complete` handler do implement the necessary
interfaces.

You can explicitly define how to handle conditional `GET` through `stale?` or
`fresh_when`:

```ruby
DocRepo.request(params[:slug]) do |on|
  on.complete do |doc|
    @doc = doc
    fresh_when strong_etag: doc.cache_key_with_version, last_modified: doc.last_modified
  end
end
```

Alternatively, you can provide the document instance directly:

```ruby
DocRepo.request(params[:slug]) do |on|
  on.complete do |doc|
    @doc = doc
    fresh_when @doc
  end
end
```

This also applies to view caches:

```erb
<% cache @doc do %>
  <%== @doc.to_html %>
<% end %>
```

#### Rails 5.1 and Earlier Cache Keys

The gem will attempt to check the Rails version when it is loaded and the
`Rails` module is defined. When it detects a version prior to 5.2 it will load
a patch which retains the legacy behavior of `DocRepo::Doc#cache_key`
containing version information. On theses versions of Rails
`DocRepo::Doc#cache_key_with_version` will simply be an alias for `cache_key`.

#### Rails 5.2 Recyclable View Caches

Support for this feature is built-in. The default implementation for
`DocRepo::Doc#cache_key` does not include the version. Additionally,
`DocRepo::Doc#cache_key_with_version` is already available to provide a
versioned implementation. This means Rails view caches can be recycled while
conditional `GET` calls through `fresh_when` and `stale?` continue to behave as
expected.

While we do not suggest it, if you wish to explicitly retain the legacy
`cache_key` behavior then you will need to load it through an initializer:

```ruby
# config/initializers/doc_repo.rb
require 'doc_repo/rails/legacy_versioned_cache'
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License.  See the [LICENSE file](LICENSE.txt) for details.
