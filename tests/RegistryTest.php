<?php
use PHPUnit\Framework\TestCase;

/**
 * The loader must pick the newest copy, whatever order the plugins load in.
 */
final class RegistryTest extends TestCase {

	public static function setUpBeforeClass(): void {
		require_once dirname( __DIR__ ) . '/load.php';
	}

	public function test_registers_itself_and_hooks_boot(): void {
		$this->assertSame( '1.0.0', MLAB_License_Client_Registry::newest() );
		$this->assertContains( array( 'plugins_loaded', 'mlab_license', 0 ), $GLOBALS['mlab_test_actions'] );
	}

	public function test_newest_version_wins(): void {
		MLAB_License_Client_Registry::add( '1.2.0', '/copy-b' );
		MLAB_License_Client_Registry::add( '1.10.0', '/copy-c' );
		MLAB_License_Client_Registry::add( '1.9.3', '/copy-d' );
		$this->assertSame( '1.10.0', MLAB_License_Client_Registry::newest() );
	}

	public function test_loading_a_second_copy_does_not_redeclare(): void {
		require dirname( __DIR__ ) . '/load.php';
		$this->assertTrue( function_exists( 'mlab_license' ) );
	}
}
