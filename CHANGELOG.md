## [Unreleased]

- Add `parse_resource` method (aliased as `deserialize_resource`) for parsing
  JSON:API payloads into Sawyer::Resource objects with dot-notation access.
  Useful for parsing webhook payloads or raw API responses.
- Add Booqable::RefreshTokenRevoked and Booqable::InvalidGrant error types for
  invalid grant OAuth response scenarios
- Add "all" as an alias for "list" method on all resources. 
  You can now use `Booqable.orders.all` as an alternative to `Booqable.orders.list`.

## [1.0.0] - 2025-10-23

- Initial release
