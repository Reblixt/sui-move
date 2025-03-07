module nft_factory::factory {
    use nft::nft::{send_objects, new};
    use std::{debug, string::utf8};
    use sui::package::{Self, Publisher};

    public struct FACTORY has drop {}

    fun init(otw: FACTORY, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx);
    }

    #[allow(lint(share_owned, self_transfer))]
    public fun create(publisher: &Publisher, ctx: &mut TxContext) {
        let (collection_display, nft_display, owner_cap, mut collection, policy, policy_cap) = new<
            FACTORY,
        >(
            publisher,
            utf8(b"Test Collection"),
            utf8(b"https://example.com/image.png"),
            utf8(b"https://example.com/banner.png"),
            utf8(b"Test Collection Description"),
            utf8(b"https://example.com/project"),
            utf8(b"Creator"),
            vector[utf8(b"Hat"), utf8(b"Background")],
            ctx,
        );

        let mut i = 0;
        debug::print(&i);
        while (i < 10) {
            let nft = collection.mint_nft(
                utf8(b"Test NFT"),
                utf8(b"https://example.com/image.png"),
                utf8(b"https://example.com/banner.png"),
                true,
                vector[utf8(b"Hat"), utf8(b"Background")],
                vector[utf8(b"Value 1"), utf8(b"Value 2")],
                &owner_cap,
                ctx,
            );
            transfer::public_transfer(nft, ctx.sender());
            i = i + 1;
        };

        collection.share_collection();
        transfer::public_share_object(policy);
        send_objects<FACTORY>(
            policy_cap,
            collection_display,
            nft_display,
            owner_cap,
            ctx,
        );
    }
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = FACTORY {};
        init(otw, ctx);
    }
}
