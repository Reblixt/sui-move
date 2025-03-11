module example::nft_example {
    use nft::collectible::{Self, CollectionCap, CollectionTicket, Registry, Collectible};
    use std::{option::{Self, some}, string::{String, utf8}};
    use sui::{borrow::Borrow, display::{Self, Display}};

    // use sui::package::{Self, Publisher};

    public struct FACTORY has drop {}

    public struct Nft<phantom T> has key, store {
        id: UID,
    }

    fun init(otw: FACTORY, ctx: &mut TxContext) {
        collectible::claim_ticket<FACTORY, Nft<FACTORY>>(otw, option::some(100), ctx);
    }

    #[allow(lint(self_transfer))]
    public fun create_and_mint<T: store>(
        ticket: CollectionTicket<T>,
        registry: &Registry,
        name: String,
        image_url: String,
        description: String,
        types: vector<String>,
        values: vector<String>,
        creator: String,
        ctx: &mut TxContext,
    ) {
        let mut collection_cap: CollectionCap<T> = ticket.create_collection(
            registry,
            false,
            types,
            values,
            ctx,
        );

        let collectible = collection_cap.mint(
            image_url,
            some(name),
            some(description),
            some(creator),
            some(types),
            some(values),
            option::none(),
            ctx,
        );

        // let (mut display, borrow): (
        //     Display<Collectible<T>>,
        //     Borrow,
        // ) = collection_cap.borrow_display();
        //
        // display::add_multiple(&mut display, types, values);
        //
        // collection_cap.return_display(display, borrow);

        transfer::public_transfer(collection_cap, ctx.sender());
        transfer::public_transfer(collectible, ctx.sender());
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = FACTORY {};
        init(otw, ctx);
    }
}
