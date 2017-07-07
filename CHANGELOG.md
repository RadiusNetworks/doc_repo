## Development

[Full Changelog](http://github.com/RadiusNetworks/doc_repo/compare/v0.1.1...master)

Enhancements:

- Add support for 2.4 (Aaron Kromer, #5)
- Add new configuration settings (Aaron Kromer, #8)
  - `cache_options`
  - `cache_store`
  - `doc_formats`
  - `doc_root`
  - `fallback_ext`
- Add ability to provide custom error handling through callback to avoid
  control flow by exception (Aaron Kromer, #8)
- Provide ability to specify separate `not_found` and `error` handlers with
  `not_found` falling back to the `error` handler when not set (Aaron Kromer,
  #8)
- Support local HTTP cache reducing remote origin requests (Aaron Kromer, #8)
- Further Reduce remote origin requests through use of `Expires` header with
  conditional `GET` requests using `If-None-Match` and `If-Modified-Since` when
  local HTTP cache is configured (Aaron Kromer, #8)
- Support Rails view caching of `DocRepo::Doc` instances (Aaron Kromer, #8)
- Support Rails 5.2 recyclable view caches for `DocRepo::Doc` instances (Aaron
  Kromer, #8)
- Support Rails conditional `GET` through `fresh_when` and `stale?` for
  `DocRepo::Doc` instances (Aaron Kromer, #8)

Bug Fixes:

- Add back the `DocRepo.configuration=` writer (Aaron Kromer, #5)

Breaking Changes:

- Drop support for Ruby 2.0, 2.1, and 2.2 (Aaron Kromer, #5)
- Drop support for Ruby 2.3 (Aaron Kromer, #8)
- Drop support for inheriting configuration from `ENV` (Aaron Kromer, #8)
- Drop the following classes (Aaron Kromer, #8)
  - `DocRepo::BadPageFormat`
  - `DocRepo::NotFound`
  - `DocRepo::GithubFile`
  - `DocRepo::Page`
  - `DocRepo::Response`
- `DocRepo#respond_with` is now `DocRepo#request` and the object yielded
  to the block uses handler blocks (Aaron Kromer, #8)
- `DocRepo::Repository` requires a `DocRepo::Configuration` on creation (Aaron
  Kromer, #8)
