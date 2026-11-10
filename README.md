# MomentumLab License Client

Shared license client for all MomentumLab WordPress plugins.

- **One key per website.** However many MomentumLab plugins are installed, the customer enters the license key once.
- **Works with and without MomentumLab Core.** With Core, the key is managed on the central *MomentumLab* page and every plugin only shows a link there. Without Core, each plugin shows the same license box; they all share the same key.
- **Never slows down the website.** The license server is asked only in the admin, in WP-Cron or WP-CLI (twice a day, 5 s timeout). In the frontend, `unlocked()` reads the stored answer.
- **Never breaks the website.** An expired license switches paid features off; free features keep working. If the server cannot be reached, unlocked features keep working for 7 days.

## How it is shipped

The library is not a plugin and customers never install it. Every plugin bundles a copy in `lib/mlab-license-client/`. All copies on a site register themselves; the newest version is booted once, the others stay idle (the same approach as Plugin Update Checker).

```bash
bin/sync-to.sh ../mlab-seo
```

## Use in a plugin

```php
// Main plugin file.
require_once __DIR__ . '/lib/mlab-license-client/load.php';

// From "plugins_loaded" on:
if ( mlab_license()->unlocked( 'mlab-seo-pro' ) ) {
	// Pro features.
}

// Settings page:
mlab_license()->render_box( 'mlab-seo-pro' );
```

| Method | HTTP | Purpose |
|---|---|---|
| `unlocked( $slug )` | no | Whether the license unlocks a product or feature slug. |
| `products()` | no | Products of the last catalog (name, version, main file, unlocked). |
| `state()` | no | `status` (`none`, `valid`, `invalid`, `unreachable`), `message`, times. |
| `refresh( $force )` | admin/cron only | Asks the server when the answer is older than 12 h (or always with `$force`). |
| `save_key( $key )` | yes | Stores and checks a key; `''` removes it. |
| `request_args()` | no | Headers and timeout for other requests to the server, e.g. update checks. |
| `render_box( $slug )` | no | License box; a link only when a central page exists. |

Hooks:

- `mlab_license_changed` (action): the set of unlocked products changed.
- `mlab_license_admin_url` (filter): URL of the central license page; MomentumLab Core sets it.

Constants in `wp-config.php` (optional):

- `MLAB_LICENSE_KEY`: fixes the key; the form is locked.
- `MLAB_LICENSE_SERVER_URL`: other server, for tests only.

Keys stored by older versions of MomentumLab Core (`mlab_core_license_key`) or MomentumLab SEO (`mlab_seo_license`) are taken over once.

## Products on the license server

Paid features get their own unlock slug without a download, for example `mlab-seo` (free plugin, updates for everyone) and `mlab-seo-pro` (paid unlock). A free product is unlocked for everyone, so it must never be used to gate paid features.

## Versioning

`load.php` registers the version of the copy (`MLAB_License_Client_Registry::add( 'x.y.z', … )`) and must stay backwards compatible. Classes live in `MomentumLab\LicenseClient\V1`; a breaking change needs a new namespace.

## Development

```bash
composer install
composer test
composer lint
```
