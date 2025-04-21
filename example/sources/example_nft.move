module example::nft_example {
    use nft::collectible::{
        Self,
        CollectionCap,
        CollectionTicket,
        Registry,
        Collection,
        Collectible
    };
    use std::{option::{Self, some}, string::{String, utf8}};
    use sui::{borrow::Borrow, display::Display};

    // use sui::{borrow::Borrow, display::{Self, Display}};

    // use sui::package::{Self, Publisher};

    public struct NFT_EXAMPLE has drop {}

    public struct Nft<phantom T> has key, store {
        id: UID,
    }

    fun init(otw: NFT_EXAMPLE, ctx: &mut TxContext) {
        collectible::claim_ticket<NFT_EXAMPLE, Nft<NFT_EXAMPLE>>(otw, option::some(100), ctx);
    }

    #[allow(lint(self_transfer))]
    public fun collection_init(
        ticket: CollectionTicket<Nft<NFT_EXAMPLE>>,
        registry: &Registry,
        // name: String,
        banner_url: String,
        // image_url: String,
        // description: String,
        keys: vector<String>,
        // values: vector<String>,
        // creator: String,
        ctx: &mut TxContext,
    ) {
        let (mut collection, cap): (
            Collection<Nft<NFT_EXAMPLE>>,
            CollectionCap<Nft<NFT_EXAMPLE>>,
        ) = ticket.create_collection(
            registry,
            banner_url,
            keys,
            some(b"carl".to_string()),
            false,
            true,
            ctx,
        );

        let (mut display, borrow) = collection.borrow_mut_display_collectible(&cap);

        display.add(b"project_url".to_string(), b"www.project.com".to_string());
        display.update_version();

        collection.return_display_collectible(display, borrow);

        transfer::public_transfer(collection, ctx.sender());
        transfer::public_transfer(cap, ctx.sender());
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = NFT_EXAMPLE {};
        init(otw, ctx);
    }
}
