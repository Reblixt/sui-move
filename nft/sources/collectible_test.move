module nft::collectible_test {
    use kiosk::collectible::{Self, Registry, CollectionTicket};
    use std::{option::{Self, some}, string::String};

    public struct COLLECTIBLE_TEST has drop {}
    public struct Nft<phantom T> has key, store {
        id: UID,
    }

    fun init(otw: COLLECTIBLE_TEST, ctx: &mut TxContext) {
        let max_supply = option::some(100);
        collectible::claim_ticket<COLLECTIBLE_TEST, Nft<COLLECTIBLE_TEST>>(otw, max_supply, ctx);
    }

    #[allow(lint(self_transfer))]
    public fun create_coll_and_mint<T: store>(
        registry: &Registry,
        ticket: CollectionTicket<T>,
        image_url: String,
        name: String,
        description: String,
        creator: String,
        ctx: &mut TxContext,
    ) {
        let mut collection_cap = collectible::create_collection(registry, ticket, ctx);
        let collectible = collection_cap.mint(
            image_url,
            some(name),
            some(description),
            some(creator),
            option::none(),
            ctx,
        );

        transfer::public_transfer(collection_cap, ctx.sender());
        transfer::public_transfer(collectible, ctx.sender());
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = COLLECTIBLE_TEST {};
        init(otw, ctx);
    }
}
