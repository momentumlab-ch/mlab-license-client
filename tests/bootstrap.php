<?php
/**
 * Test bootstrap: pure classes, no WordPress.
 */

define( 'ABSPATH', __DIR__ . '/' );

$GLOBALS['mlab_test_actions'] = array();
if ( ! function_exists( 'add_action' ) ) {
	function add_action( $hook, $callback, $priority = 10 ) {
		$GLOBALS['mlab_test_actions'][] = array( $hook, $callback, $priority );
		return true;
	}
}

require_once dirname( __DIR__ ) . '/src/class-state.php';
