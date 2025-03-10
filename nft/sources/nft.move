module nft::nft {
    use std::{hash::sha2_256, string::{Self, String, utf8}};
    use sui::{
        bag::{Self, Bag},
        display::{Display, new_with_fields},
        event::emit,
        package::{Self, Publisher},
        transfer::{public_transfer, share_object, public_share_object},
        transfer_policy::{Self as policy, TransferPolicy, TransferPolicyCap}
    };

    public struct NFT has drop {}

    public struct Collection<phantom T> has key {
        id: UID,
        nftCount: u64,
        nftIds: vector<ID>,
        attribute_types: vector<String>,
        name: String,
        image_url: String,
        banner_url: String,
        description: String,
        project_url: String,
        creator: String,
    }

    public struct Nft<phantom T> has key, store {
        id: UID,
        name: String,
        image_url: String,
        description: String,
        attributes: Bag,
        burnable: bool,
    }

    public struct Attribute has drop, store {
        key: String,
        value: String,
    }

    public struct OwnerCap<phantom T> has key, store {
        id: UID,
    }

    // ============= Events =============

    public struct NewCollectionEvent<phantom T> has copy, drop {
        collection: ID,
    }

    public struct MintNftEvent<phantom T> has copy, drop {
        collection: ID,
        nft: ID,
    }

    // ============= Error Codes =============
    const ENotSameLength: u64 = 401;
    const EAttributeNotAllowed: u64 = 402;
    const ENotBurnable: u64 = 403;

    fun init(otw: NFT, ctx: &mut TxContext) {
        package::claim_and_keep<NFT>(otw, ctx);
        let collection = Collection<NFT> {
            id: object::new(ctx),
            nftCount: 0,
            nftIds: vector[],
            attribute_types: vector[],
            name: utf8(b""),
            image_url: utf8(b""),
            banner_url: utf8(b""),
            description: utf8(b""),
            project_url: utf8(b""),
            creator: utf8(b""),
        };

        let owner_cap = OwnerCap<NFT> { id: object::new(ctx) };

        emit(NewCollectionEvent<NFT> { collection: object::id(&collection) });

        share_object(collection);
        transfer::transfer(owner_cap, ctx.sender());
    }

    #[allow(lint(self_transfer, share_owned))]
    public fun set_up_collection<T>(
        collection: &mut Collection<T>,
        publisher: &Publisher,
        name: String,
        image_url: String,
        banner_url: String,
        description: String,
        project_url: String,
        creator: String,
        // Optional
        // royalty_amount: Option<u64>,
        // royalty_min_amount: Option<u64>,
        _: &OwnerCap<T>,
        ctx: &mut TxContext,
    ) {
        collection.name = name;
        collection.image_url = image_url;
        collection.banner_url = banner_url;
        collection.description = description;
        collection.project_url = project_url;
        collection.creator = creator;
        let (transfer_policy, policy_cap) = policy::new<NFT>(publisher, ctx);

        let collection_display = prepare_collection_display<NFT>(publisher, creator, ctx);
        let nft_display = prepare_nft_display<NFT>(publisher, ctx);
        public_share_object(transfer_policy);
        send_objects(policy_cap, collection_display, nft_display, ctx);
    }

    public fun mint_nft<T>(
        collection: &mut Collection<T>,
        name: String,
        image_url: String,
        desc: String,
        burnable: bool,
        att_type: vector<String>,
        att_value: vector<String>,
        _: &OwnerCap<T>,
        ctx: &mut TxContext,
    ): Nft<T> {
        let mut newBag = bag::new(ctx);
        assert!(vector::length(&att_type) == vector::length(&att_value), ENotSameLength);

        let mut i = 0;
        while (i < vector::length(&att_type)) {
            assert!(collection.attribute_types.contains(&att_type[i]), EAttributeNotAllowed);
            let attribute = Attribute {
                key: att_type[i],
                value: att_value[i],
            };
            bag::add(&mut newBag, att_type[i], attribute);
            i = i + 1;
        };

        let nft = Nft<T> {
            id: object::new(ctx),
            name,
            image_url,
            description: desc,
            attributes: newBag,
            burnable,
        };

        collection.nftCount = collection.nftCount + 1;
        collection.nftIds.push_back(object::id(&nft));

        emit(MintNftEvent<T> { collection: object::id(collection), nft: object::id(&nft) });
        nft
    }

    public fun burn_nft<T>(
        self: Nft<T>,
        collection: &mut Collection<T>,
        _: &OwnerCap<T>,
        _: &mut TxContext,
    ) {
        assert!(self.burnable, ENotBurnable);
        let attributes_types: vector<String> = collection.attribute_types;

        let Nft<T> {
            id,
            name: _,
            image_url: _,
            description: _,
            mut attributes,
            burnable: _,
        } = self;

        if (!bag::is_empty(&attributes)) {
            let mut i = 0;
            while (bag::length(&attributes) > 0) {
                if (attributes.contains<String>(attributes_types[i])) {
                    let _ = attributes.remove<String, Attribute>(attributes_types[i]);
                };

                i = i + 1;
            };
        };

        collection.nftCount = collection.nftCount - 1;
        let (truthy, index) = collection.nftIds.index_of<ID>(id.as_inner());
        if (truthy) {
            collection.nftIds.remove(index);
        };

        attributes.destroy_empty();
        id.delete();
    }

    public fun create_attribute_hash<T>(
        collection: &Collection<T>,
        keys: vector<String>,
        values: vector<String>,
    ): vector<u8> {
        assert!(vector::length(&keys) == vector::length(&values), ENotSameLength);
        let types = collection.attribute_types;
        let mut attribute_hash = vector<u8>[];

        let mut i = 0;
        while (i < vector::length(&keys)) {
            assert!(types.contains(&keys[i]), EAttributeNotAllowed);
            vector::append(&mut attribute_hash, string::into_bytes(values[i]));
            i = i + 1;
        };

        let hashed_attribute = sha2_256(attribute_hash);
        hashed_attribute
    }

    public fun validate_attribute<T>(
        nft: &Nft<T>,
        hashed_attribute: vector<u8>,
        keys: vector<String>,
    ): bool {
        let mut attribute_hash = vector<u8>[];

        let mut i = 0;
        while (i < vector::length(&keys)) {
            let attribute = bag::borrow<String, Attribute>(&nft.attributes, keys[i]);
            vector::append(&mut attribute_hash, string::into_bytes(attribute.value));
            i = i + 1;
        };

        let actual_attribute_hash = sha2_256(attribute_hash);
        let equal: bool = actual_attribute_hash == hashed_attribute;

        equal
    }

    #[allow(lint(self_transfer))]
    public fun send_objects<T>(
        policy_cap: TransferPolicyCap<T>,
        collection_display: Display<Collection<T>>,
        nft_display: Display<Nft<T>>,
        ctx: &mut TxContext,
    ) {
        public_transfer(policy_cap, ctx.sender());
        public_transfer(collection_display, ctx.sender());
        public_transfer(nft_display, ctx.sender());
    }

    fun prepare_collection_display<T>(
        publisher: &Publisher,
        creator: String,
        ctx: &mut TxContext,
    ): Display<Collection<T>> {
        let collection_keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"banner_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let collection_values = vector[
            utf8(b"{name}"),
            utf8(b"{image_url}"),
            utf8(b"{banner_url}"),
            utf8(b"{description}"),
            utf8(b"{project_url}"),
            creator,
        ];

        let mut collection_display = new_with_fields(
            publisher,
            collection_keys,
            collection_values,
            ctx,
        );
        collection_display.update_version();

        collection_display
    }

    fun prepare_nft_display<T>(publisher: &Publisher, ctx: &mut TxContext): Display<Nft<T>> {
        let nft_keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"attributes"),
            utf8(b"burnable"),
        ];
        let nft_values = vector[
            utf8(b"{name}"),
            utf8(b"{image_url}"),
            utf8(b"{description}"),
            utf8(b"{attributes}"),
            utf8(b"{burnable}"),
        ];

        let mut nft_display: Display<Nft<T>> = new_with_fields(
            publisher,
            nft_keys,
            nft_values,
            ctx,
        );
        nft_display.update_version();

        nft_display
    }
}
