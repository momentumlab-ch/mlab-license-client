#!/usr/bin/env bash
# Integration check: MomentumLab License Server + MomentumLab SEO (with this client) on one WordPress.
# Env: LS_DIR (mlab-license-server checkout), SEO_DIR (mlab-seo checkout with lib/mlab-license-client),
#      WP_SRC, SQLITE_SRC, WP_CLI (optional; downloaded when missing).
set -uo pipefail

LS_DIR="${LS_DIR:?Set LS_DIR to the mlab-license-server checkout}"
SEO_DIR="${SEO_DIR:?Set SEO_DIR to the mlab-seo checkout}"
WORK="$(mktemp -d)"
PORT=8898
BASE="http://127.0.0.1:${PORT}"
SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

[ -n "${WP_SRC:-}" ] || { WP_SRC="$WORK/src-wp"; git clone --quiet --depth 1 --branch 6.8.3 https://github.com/WordPress/WordPress.git "$WP_SRC" || exit 1; }
[ -n "${SQLITE_SRC:-}" ] || { SQLITE_SRC="$WORK/src-sqlite"; git clone --quiet --depth 1 https://github.com/WordPress/sqlite-database-integration.git "$SQLITE_SRC" || exit 1; }
[ -n "${WP_CLI:-}" ] || { WP_CLI="$WORK/wp-cli.phar"; curl -fsSL -o "$WP_CLI" https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar || exit 1; }
SQLITE_PLUGIN_SRC="$SQLITE_SRC"
[ -d "$SQLITE_SRC/packages/plugin-sqlite-database-integration" ] && SQLITE_PLUGIN_SRC="$SQLITE_SRC/packages/plugin-sqlite-database-integration"

SITE="$WORK/site"
mkdir -p "$SITE"
cp -r "$WP_SRC/." "$SITE/" && rm -rf "$SITE/.git"
cp -rL "$SQLITE_PLUGIN_SRC" "$SITE/wp-content/plugins/sqlite-database-integration"
sed -e "s#{SQLITE_IMPLEMENTATION_FOLDER_PATH}#$SITE/wp-content/plugins/sqlite-database-integration#" \
	-e "s#{SQLITE_PLUGIN}#sqlite-database-integration/load.php#" \
	"$SITE/wp-content/plugins/sqlite-database-integration/db.copy" > "$SITE/wp-content/db.php"
ln -s "$LS_DIR" "$SITE/wp-content/plugins/mlab-license-server"
ln -s "$SEO_DIR" "$SITE/wp-content/plugins/mlab-seo"

# Router for the built-in server: real files as they are, everything else to WordPress (like a rewrite rule).
cat > "$SITE/router.php" <<'PHP'
<?php
$path = __DIR__ . parse_url( $_SERVER['REQUEST_URI'], PHP_URL_PATH );
if ( '/' !== $_SERVER['REQUEST_URI'] && is_file( $path ) ) {
	return false;
}
$_SERVER['SCRIPT_NAME'] = '/index.php';
require __DIR__ . '/index.php';
PHP

cat > "$SITE/wp-config.php" <<PHP
<?php
define( 'DB_NAME', 'wp' ); define( 'DB_USER', '' ); define( 'DB_PASSWORD', '' ); define( 'DB_HOST', '' );
define( 'DB_CHARSET', 'utf8' ); define( 'DB_COLLATE', '' ); define( 'WP_DEBUG', false );
define( 'MLAB_LS_SIGNING_KEY', 'integration-signing-key-0123456789abcdef0123456789' );
define( 'MLAB_LICENSE_SERVER_URL', '$BASE' );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) { define( 'ABSPATH', __DIR__ . '/' ); }
require_once ABSPATH . 'wp-settings.php';
PHP

wp() { php "$WP_CLI" --path="$SITE" --allow-root "$@"; }
wp core install --url="$BASE" --title=Integration --admin_user=admin --admin_password=integration-pass --admin_email=admin@example.com --skip-email >/dev/null || { echo "WordPress install failed"; exit 1; }
wp option update siteurl "$BASE" >/dev/null; wp option update home "$BASE" >/dev/null
wp rewrite structure '/%postname%/' >/dev/null
wp plugin activate mlab-license-server mlab-seo >/dev/null || { echo "Plugin activation failed"; exit 1; }

KEY="$(wp eval '
use MomentumLab\LicenseServer\Store; use MomentumLab\LicenseServer\Licensing;
Store::save_product( array( "slug" => "mlab-seo", "name" => "SEO", "description" => "", "repo" => "momentumlab-ch/mlab-seo", "main_file" => "mlab-seo/mlab-seo.php", "is_private" => 0, "is_free" => 1, "is_active" => 1 ) );
$pro = Store::save_product( array( "slug" => "mlab-seo-pro", "name" => "SEO Pro", "description" => "", "repo" => "", "main_file" => "", "is_private" => 0, "is_free" => 0, "is_active" => 1 ) );
$c = Licensing::create( array( "customer_name" => "Kunde", "customer_email" => "k@example.com", "max_sites" => 1 ), "product:" . $pro, "1y" );
echo $c["key"];
')" || { echo "Seeding failed"; exit 1; }
LIC_ID="$(wp eval 'echo MomentumLab\LicenseServer\Store::license_by_key( "'"$KEY"'" )["id"];')"

(cd "$SITE" && php -S "127.0.0.1:${PORT}" router.php) >"$WORK/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "$BASE/" && break; sleep 0.2; done

FAILS=0
check() { if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS + 1)); fi; }
pro() { wp eval 'echo MomentumLab\SEO\License::is_pro() ? "pro" : "free";'; }
# WP-CLI counts as a place where the client may ask the server.
refresh() { wp eval 'mlab_license()->refresh( true );' >/dev/null; }

[ "$(pro)" = free ]; check "1 without key: free" $?

wp eval 'MomentumLab\SEO\License::activate( "'"$KEY"'" );' >/dev/null
[ "$(pro)" = pro ]; check "2 key entered in SEO: Pro unlocked" $?

SEO_KEY="$(wp eval 'echo mlab_license()->key();')"
[ "$SEO_KEY" = "$KEY" ]; check "3 key stored once for all MomentumLab plugins" $?

wp eval 'MomentumLab\LicenseServer\Store::update_license( '"$LIC_ID"', array( "expires_at" => time() - 60 ) );' >/dev/null
refresh
[ "$(pro)" = free ]; check "4 expired license: Pro off, plugin keeps running" $?

wp eval 'MomentumLab\LicenseServer\Licensing::extend( '"$LIC_ID"' );' >/dev/null
refresh
[ "$(pro)" = pro ]; check "5 extended license: Pro on again" $?

kill "$SERVER_PID" 2>/dev/null; SERVER_PID=""
refresh
[ "$(pro)" = pro ]; check "6 server unreachable: Pro stays on (grace)" $?
STATUS="$(wp eval 'echo mlab_license()->state()["status"];')"
[ "$STATUS" = unreachable ]; check "7 outage is recorded as unreachable ($STATUS)" $?

wp eval 'delete_option( "mlab_license_key" ); delete_option( "mlab_license_state" ); update_option( "mlab_seo_license", array( "key" => "'"$KEY"'", "status" => "valid" ) );' >/dev/null
(cd "$SITE" && php -S "127.0.0.1:${PORT}" router.php) >>"$WORK/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "$BASE/" && break; sleep 0.2; done
wp eval 'mlab_license()->adopt_legacy_key();' >/dev/null
[ "$(wp eval 'echo mlab_license()->key();')" = "$KEY" ] && [ "$(pro)" = pro ]; check "8 key of the former SEO licence is taken over" $?

FRONT="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")"
[ "$FRONT" = 200 ]; check "9 frontend loads ($FRONT)" $?

[ "$FAILS" -eq 0 ] || { echo "$FAILS check(s) failed"; tail -n 20 "$WORK/server.log"; exit 1; }
echo "All checks passed"
