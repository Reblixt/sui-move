#[test_only]
module nft_factory::nft_factory_tests {
    use nft_factory::factory;
    use sui::{package::Publisher, test_scenario, test_utils::destroy};

    // const ENotImplemented: u64 = 0;
    const Alice: address = @0x1ABE;

    #[test]
    fun test_nft_factory() {
        let mut scen = test_scenario::begin(Alice);
        scen.next_tx(Alice);

        factory::test_init(scen.ctx());
        scen.next_tx(Alice);
        scen.end();
    }
}

// #[test, expected_failure(abort_code = ::nft_factory::nft_factory_tests::ENotImplemented)]
// fun test_nft_factory_fail() {
//     abort ENotImplemented
// }
