<?php
use MomentumLab\LicenseClient\V1\State;
use PHPUnit\Framework\TestCase;

final class StateTest extends TestCase {

	private const NOW = 1800000000;

	private function catalog( bool $pro ): array {
		return array(
			'products' => array(
				array( 'slug' => 'mlab-seo', 'name' => 'SEO', 'unlocked' => true ),
				array( 'slug' => 'mlab-seo-pro', 'name' => 'SEO Pro', 'unlocked' => $pro ),
			),
		);
	}

	private function valid( bool $pro = true ): array {
		return State::after_response( State::blank(), 200, $this->catalog( $pro ), self::NOW, 'down' );
	}

	public function test_no_key_unlocks_nothing(): void {
		$this->assertFalse( State::unlocked( State::blank(), 'mlab-seo', self::NOW ) );
	}

	public function test_valid_answer_unlocks_what_the_server_says(): void {
		$this->assertTrue( State::unlocked( $this->valid(), 'mlab-seo-pro', self::NOW ) );
		$this->assertFalse( State::unlocked( $this->valid( false ), 'mlab-seo-pro', self::NOW ) );
		$this->assertFalse( State::unlocked( $this->valid(), 'unknown', self::NOW ) );
	}

	public function test_expired_or_blocked_license_locks_but_keeps_the_list(): void {
		$state = State::after_response( $this->valid(), 403, array( 'message' => 'Expired' ), self::NOW + 10, 'down' );
		$this->assertSame( State::INVALID, $state['status'] );
		$this->assertSame( 'Expired', $state['message'] );
		$this->assertCount( 2, $state['products'] );
		$this->assertFalse( State::unlocked( $state, 'mlab-seo-pro', self::NOW + 10 ) );
	}

	public function test_unknown_key_locks(): void {
		$state = State::after_response( $this->valid(), 401, null, self::NOW, 'down' );
		$this->assertFalse( State::unlocked( $state, 'mlab-seo-pro', self::NOW ) );
		$this->assertSame( 'down', $state['message'] );
	}

	public function test_outage_keeps_pro_for_seven_days(): void {
		$state = State::after_response( $this->valid(), 0, null, self::NOW + 100, 'down' );
		$this->assertSame( State::UNREACHABLE, $state['status'] );
		$this->assertTrue( State::unlocked( $state, 'mlab-seo-pro', self::NOW + State::GRACE - 1 ) );
		$this->assertFalse( State::unlocked( $state, 'mlab-seo-pro', self::NOW + State::GRACE ) );
	}

	public function test_server_error_counts_as_outage(): void {
		$state = State::after_response( $this->valid(), 500, array( 'message' => 'Oops' ), self::NOW, 'down' );
		$this->assertSame( State::UNREACHABLE, $state['status'] );
		$this->assertTrue( State::unlocked( $state, 'mlab-seo-pro', self::NOW ) );
	}

	public function test_outage_without_any_good_answer_unlocks_nothing(): void {
		$state = State::after_response( State::blank(), 0, null, self::NOW, 'down' );
		$this->assertFalse( State::unlocked( $state, 'mlab-seo', self::NOW ) );
	}

	public function test_due_after_ttl_or_retry_gap(): void {
		$state = $this->valid();
		$this->assertFalse( State::due( $state, self::NOW + State::TTL - 1 ) );
		$this->assertTrue( State::due( $state, self::NOW + State::TTL ) );
		$failed = State::after_response( $state, 0, null, self::NOW + 10, 'down' );
		$this->assertFalse( State::due( $failed, self::NOW + 10 + State::RETRY - 1 ) );
		$this->assertTrue( State::due( $failed, self::NOW + 10 + State::RETRY ) );
	}

	public function test_bad_products_are_dropped(): void {
		$body  = array( 'products' => array( array( 'slug' => '../x', 'unlocked' => true ), 'junk', array( 'slug' => 'ok', 'unlocked' => 1 ) ) );
		$state = State::after_response( State::blank(), 200, $body, self::NOW, 'down' );
		$this->assertSame( array( 'ok' ), array_column( $state['products'], 'slug' ) );
		$this->assertTrue( $state['products'][0]['unlocked'] );
	}

	public function test_normalize_fills_missing_keys(): void {
		$state = State::normalize( 'garbage' );
		$this->assertSame( State::NONE, $state['status'] );
		$this->assertSame( array(), $state['products'] );
	}

	public function test_ping_allowed_without_stored_value(): void {
		$this->assertTrue( State::ping_allowed( null, self::NOW ) );
		$this->assertTrue( State::ping_allowed( false, self::NOW ) );
		$this->assertTrue( State::ping_allowed( '', self::NOW ) );
		$this->assertTrue( State::ping_allowed( 0, self::NOW ) );
	}

	public function test_ping_is_throttled_to_one_per_minute(): void {
		$this->assertFalse( State::ping_allowed( self::NOW, self::NOW ) );
		$this->assertFalse( State::ping_allowed( self::NOW - 59, self::NOW ) );
		$this->assertTrue( State::ping_allowed( self::NOW - 60, self::NOW ) );
		$this->assertTrue( State::ping_allowed( (string) ( self::NOW - 61 ), self::NOW ) );
	}

	public function test_ping_in_the_future_is_throttled(): void {
		$this->assertFalse( State::ping_allowed( self::NOW + 30, self::NOW ) );
	}
}
