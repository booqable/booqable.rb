## [2.1.0] - 2026-07-16

- Add the `app_issues` resource (CRUD for `App::Issue`).
- Fix: a to-one relationship serialized with `"data": null` (e.g. a charge
  line's `item`, or an included `barcode` on a product without one) now reads
  as nil, matching the present-with-null attribute semantics — instead of the
  parser dropping the key and the read raising `Booqable::MissingAttribute`.

## [2.0.0] - 2026-07-14

- **Breaking:** reading an attribute that is absent from an API payload now
  raises `Booqable::MissingAttribute` (a `NoMethodError` subclass) instead of
  silently returning nil.
- Support Ruby 4.0
- Require `cgi` and declare it as a runtime dependency. Fixes
  `undefined method 'parse' for class CGI` when handling `invalid_grant`
  OAuth errors in apps that don't load the full cgi library themselves
  (e.g. Rails 8.1+, which only loads `cgi/escape`).

## [1.2.1] - 2026-06-10

- Require `oauth2 >= 2.0.22` to address GHSA-pp92-crg2-gfv9, where a
  protocol-relative redirect `Location` could override the request authority and
  leak the bearer `Authorization` header to an attacker-controlled host.


## [1.2.0] - 2026-05-27

- Add optional `around_refresh_token` configuration. When provided, the OAuth
  middleware yields the read + expiry-check + refresh sequence to the callable
  so host applications can serialize concurrent token refreshes (e.g. with a
  database transaction and advisory lock). The gem keeps no lock dependency.


## [1.1.0] - 2026-03-11

- Add `parse_resource` method (aliased as `deserialize_resource`) for parsing
  JSON:API payloads into Sawyer::Resource objects with dot-notation access.
  Useful for parsing webhook payloads or raw API responses.
- Add Booqable::RefreshTokenRevoked and Booqable::InvalidGrant error types for
  invalid grant OAuth response scenarios
- Add "all" as an alias for "list" method on all resources. 
  You can now use `Booqable.orders.all` as an alternative to `Booqable.orders.list`.

## [1.0.0] - 2025-10-23

- Initial release
