#[test_only]
module nft::collectible_test {
    use nft::collectible::{Self as contract, Registry, CollectionTicket};
    use std::string::String;
    use sui::{test_scenario::{Self as scenario, Scenario}, test_utils::{destroy, assert_eq}};

    const Alice: address = @0x1abc;

    public struct COLLECTIBLE_TEST has drop {}

    public struct Meta has key, store {
        id: UID,
        cool: bool,
        animal: bool,
    }

    fun setup(): (Scenario, Registry, CollectionTicket<Meta>) {
        let mut scenario = scenario::begin(Alice);
        contract::test_init(scenario.ctx());
        scenario.next_tx(Alice);

        let registry = scenario.take_shared<Registry>();
        scenario.next_tx(Alice);

        let otw = COLLECTIBLE_TEST {};

        contract::claim_ticket<COLLECTIBLE_TEST, Meta>(otw, option::some(100), scenario.ctx());
        scenario.next_tx(Alice);

        let ticket = scenario.take_from_sender<CollectionTicket<Meta>>();

        (scenario, registry, ticket)
    }

    #[test]
    fun test_create_collection() {
        let (mut scen, registry, ticket) = setup();

        let banner_url = b"https://example.com/banner".to_string();
        let fields = vector[b"cool".to_string(), b"animal".to_string()];

        let (collection, coll_cap) = ticket.create_collection(
            &registry,
            banner_url,
            fields,
            option::some(b"Carl".to_string()),
            false,
            true,
            scen.ctx(),
        );
        destroy(collection);
        destroy(coll_cap);
        destroy(registry);
        scen.end();
    }
}
