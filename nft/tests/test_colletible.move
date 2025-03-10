module nft::test_coll {
    use kiosk::collectible::{Self, Registry, CollectionTicket};
    use nft::collectible_test::{Self, COLLECTIBLE_TEST, Nft};
    use sui::{test_scenario::{Self, Scenario}, test_utils::{assert_eq, destroy}};

    const Alice: address = @0x1abc;

    #[test]
    fun test_deploy() {
        let mut scen = test_scenario::begin(Alice);
        collectible_test::test_init(scen.ctx());
        // let registry = scen.take_shared<Registry>();
        scen.next_tx(Alice);

        let ticket = scen.take_from_address<CollectionTicket<Nft<COLLECTIBLE_TEST>>>(Alice);

        scen.next_tx(Alice);

        destroy(ticket);
        scen.end();

        // collectible_test::create_coll_and_mint<Nft<COLLECTIBLE_TEST>>(
        //     &registry,
        //     ticket,
        //     image_url,
        //     name,
        //     description,
        //     creator,
        //     ctx,
        // )
    }
}
