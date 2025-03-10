// SPDX-License-Identifier: MIT

module nft::collectible {
    use std::{hash::sha2_256, string::{Self, String}, vector as vec};
    use sui::{
        borrow::{Self, Referent, Borrow},
        display::{Self, Display},
        package::{Self, Publisher},
        transfer_policy::{Self as policy, TransferPolicyCap, TransferPolicy},
        tx_context::sender
    };

    /// Trying to `claim_ticket` with a non OTW struct.
    const ENotOneTimeWitness: u64 = 0;
    /// The type parameter `T` is not from the same module as the `OTW`.
    const ETypeNotFromModule: u64 = 1;
    /// Maximum size of the Collection is reached - minting forbidden.
    const ECapReached: u64 = 2;
    /// Names length does not match `image_urls` length
    const EWrongMetadatasLength: u64 = 3;
    const EWrongCollection: u64 = 4;
    const ENotBurnable: u64 = 5;
    const ENotAllCollectiblesBurned: u64 = 6;
    const EDoesNotHaveAttributes: u64 = 7;
    const ENotSameLength: u64 = 8;
    const EAttributeNotAllowed: u64 = 9;

    /// Centralized registry to provide access to system features of
    /// the Collectible.
    public struct Registry has key {
        id: UID,
        publisher: Publisher,
    }

    /// One-in-all capability wrapping all necessary functions such as
    /// `Display`, `PolicyCap` and the `Publisher`.
    public struct Collection<T: store> has key, store {
        id: UID,
        publisher: Referent<Publisher>,
        display: Referent<Display<Collectible<T>>>,
        policy_cap: Referent<TransferPolicyCap<Collectible<T>>>,
        max_supply: Option<u32>,
        attribute_types: vector<String>,
        minted: u32,
        burned: u32,
        burnable: bool,
        dynamic: bool,
    }

    public struct CollectionCap<phantom T: store> has key, store {
        id: UID,
        collection: ID,
    }

    /// Special object which connects init function and the collection
    /// initialization.
    public struct CollectionTicket<phantom T: store> has key, store {
        id: UID,
        publisher: Publisher,
        max_supply: Option<u32>,
    }

    /// Basic collectible containing most of the fields from the proposed
    /// Display set. The `metadata` field is a generic type which can be
    /// used to store any custom data.
    public struct Collectible<T: store> has key, store {
        id: UID,
        image_url: String,
        name: Option<String>,
        description: Option<String>,
        creator: Option<String>,
        attributes: Option<vector<Attribute>>,
        meta: Option<T>,
    }

    public struct Attribute has drop, store {
        a_type: String, // Background, Border, etc.
        value: String, // Red, Blue, etc.
    }

    /// OTW to initialize the Registry and the base type.
    public struct COLLECTIBLE has drop {}

    /// Create the centralized Registry of Collectibles to provide access
    /// to the Publisher functionality of the Collectible.
    fun init(otw: COLLECTIBLE, ctx: &mut TxContext) {
        transfer::share_object(Registry {
            id: object::new(ctx),
            publisher: package::claim(otw, ctx),
        })
    }

    /// Called in the external module initializer. Sends a `CollectionTicket`
    /// to the transaction sender which then enables them to initialize the
    /// Collection.
    ///
    /// - The OTW parameter is a One-Time-Witness;
    /// - The T parameter is the expected Metadata / custom type to use for
    /// the Collection;
    #[allow(lint(self_transfer))]
    public fun claim_ticket<OTW: drop, T: store>(
        otw: OTW,
        max_supply: Option<u32>,
        ctx: &mut TxContext,
    ) {
        assert!(sui::types::is_one_time_witness(&otw), ENotOneTimeWitness);

        let publisher = package::claim(otw, ctx);

        assert!(package::from_module<T>(&publisher), ETypeNotFromModule);
        transfer::transfer(
            CollectionTicket<T> {
                id: object::new(ctx),
                publisher,
                max_supply,
            },
            sender(ctx),
        );
    }

    /// Use the `CollectionTicket` to start a new collection and receive a
    /// `CollectionCap`.
    public fun create_collection<T: store>(
        ticket: CollectionTicket<T>,
        registry: &Registry,
        types: vector<String>,
        values: vector<String>,
        dynamic: bool,
        burnable: bool,
        ctx: &mut TxContext,
    ): (Collection<T>, CollectionCap<T>) {
        let CollectionTicket { id, publisher, max_supply } = ticket;
        object::delete(id);

        let mut display = display::new<Collectible<T>>(&registry.publisher, ctx);
        let (policy, policy_cap) = policy::new<Collectible<T>>(
            &registry.publisher,
            ctx,
        );

        transfer::public_share_object(policy);
        display.add_multiple(types, values);

        let collection = Collection<T> {
            id: object::new(ctx),
            display: borrow::new(display, ctx),
            publisher: borrow::new(publisher, ctx),
            policy_cap: borrow::new(policy_cap, ctx),
            max_supply,
            attribute_types: types,
            minted: 0,
            burned: 0,
            dynamic,
            burnable,
        };

        let cap = CollectionCap<T> {
            id: object::new(ctx),
            collection: object::id(&collection),
        };
        (collection, cap)
    }

    // === Minting ===

    /// Mint a single Collectible specifying the fields.
    /// Can only be performed by the owner of the `CollectionCap`.
    public fun mint<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        image_url: String,
        name: Option<String>,
        description: Option<String>,
        creator: Option<String>,
        attribute_types: Option<vector<String>>,
        attribute_values: Option<vector<String>>,
        meta: Option<T>,
        ctx: &mut TxContext,
    ): Collectible<T> {
        assert!(cap.collection == object::id(collection), EWrongCollection);
        assert!(
            option::is_none(&collection.max_supply) || *option::borrow(&collection.max_supply) > collection.minted,
            ECapReached,
        );
        collection.minted = collection.minted + 1;

        assert!(
            option::is_some(&attribute_types)
            || vec::length(option::borrow(&attribute_types))
                == vec::length(option::borrow(&attribute_values)),
            EWrongMetadatasLength,
        );

        let attributes: vector<Attribute> = if (option::is_some(&attribute_types)) {
            let types = option::destroy_some(attribute_types);
            let values = option::destroy_some(attribute_values);
            vector[
                Attribute {
                    a_type: types[0],
                    value: values[0],
                },
            ]
        } else {
            vector[]
        };

        Collectible {
            id: object::new(ctx),
            image_url,
            name,
            description,
            creator,
            attributes: option::some(attributes),
            meta,
        }
    }

    // public fun batch_mint<T: store>(
    //     cap: &mut CollectionCap<T>,
    //     image_urls: vector<String>,
    //     names: Option<vector<String>>,
    //     descriptions: Option<vector<String>>,
    //     creators: Option<vector<String>>,
    //     metas: Option<vector<T>>,
    //     ctx: &mut TxContext,
    // ) {
    //     // ): vector<Collectible<T>> {
    //     let len = vec::length(&image_urls);
    //     // let res = vec::empty();
    //
    //     // perform a dummy check to make sure collection does not overflow
    //     // safe to downcast since the length will never be greater than u32::MAX
    //     assert!(
    //         option::is_none(&cap.max_supply)
    //         || cap.minted + (len as u32) < *option::borrow(&cap.max_supply),
    //         ECapReached,
    //     );
    //
    //     assert!(
    //         option::is_none(&names)
    //         || vec::length(option::borrow(&names)) == len,
    //         EWrongNamesLength,
    //     );
    //
    //     assert!(
    //         option::is_none(&creators)
    //         || vec::length(option::borrow(&creators)) == len,
    //         EWrongCreatorsLength,
    //     );
    //
    //     assert!(
    //         option::is_none(&descriptions)
    //         || vec::length(option::borrow(&descriptions)) == len,
    //         EWrongDescriptionsLength,
    //     );
    //
    //     assert!(
    //         option::is_none(&metas)
    //         || vec::length(option::borrow(&metas)) == len,
    //         EWrongMetadatasLength,
    //     );
    //
    //     while (len > 0) {
    //         // vec::push_back(&mut res, mint(
    //         let obj = mint(
    //             cap,
    //             image_urls[len],
    //             // vec::pop_back(&mut image_urls),
    //             pop_or_none(names),
    //             pop_or_none(descriptions),
    //             pop_or_none(creators),
    //             pop_or_none(metas),
    //             ctx,
    //         );
    //
    //         sui::transfer::transfer(obj, sender(ctx));
    //         // ));
    //
    //         len = len - 1;
    //     };
    //
    //     if (option::is_some(&metas)) {
    //         let metas = option::destroy_some(metas);
    //         vec::destroy_empty(metas)
    //     } else {
    //         option::destroy_none(metas);
    //     };
    //
    //     // res
    // }

    // === Validations ===

    public fun create_attribute_hash<T: store>(
        collection: &Collection<T>,
        keys: vector<String>,
        values: vector<String>,
    ): vector<u8> {
        assert!(vector::length(&keys) == vector::length(&values), ENotSameLength);
        assert!(collection.attribute_types.length() != 0, EDoesNotHaveAttributes);
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

    // === Borrowing methods ===

    /// Take the `TransferPolicyCap` from the `CollectionCap`.
    public fun borrow_policy_cap<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (TransferPolicyCap<Collectible<T>>, Borrow) {
        borrow::borrow(&mut self.policy_cap)
    }

    /// Return the `TransferPolicyCap` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_policy_cap<T: store>(
        self: &mut Collection<T>,
        cap: TransferPolicyCap<Collectible<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.policy_cap, cap, borrow)
    }

    /// Take the `Display` from the `CollectionCap`.
    public fun borrow_display<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Display<Collectible<T>>, Borrow) {
        borrow::borrow(&mut self.display)
    }

    /// Return the `Display` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_display<T: store>(
        self: &mut Collection<T>,
        display: Display<Collectible<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.display, display, borrow)
    }

    /// Take the `Publisher` from the `CollectionCap`.
    public fun borrow_publisher<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Publisher, Borrow) {
        borrow::borrow(&mut self.publisher)
    }

    /// Return the `Publisher` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_publisher<T: store>(
        self: &mut Collection<T>,
        publisher: Publisher,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.publisher, publisher, borrow)
    }

    // === Burn ===
    public fun burn_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
        collectible: Collectible<T>,
        _: &mut TxContext,
    ): Option<T> {
        let Collectible<T> { id, meta, .. } = collectible;
        id.delete();
        self.burned = self.burned + 1;
        meta
    }

    public fun burn_collection<T: store>(
        self: Collection<T>,
        policy: TransferPolicy<Collectible<T>>,
        cap: CollectionCap<T>,
        ctx: &mut TxContext,
    ) {
        assert!(self.burnable, ENotBurnable);
        assert!(self.minted == self.burned, ENotAllCollectiblesBurned);

        let Collection<T> { id, publisher, display, policy_cap, .. } = self;
        let publisher = borrow::destroy(publisher);
        let display: Display<Collectible<T>> = borrow::destroy(display);
        let policy_cap = borrow::destroy(policy_cap);

        publisher.burn();
        let coin = policy::destroy_and_withdraw(policy, policy_cap, ctx);
        transfer::public_transfer(coin, sender(ctx));
        transfer::public_freeze_object(display);
        id.delete();
        let CollectionCap<T> { id: cap_id, .. } = cap;
        cap_id.delete();
    }

    // === Internal ===

    // fun pop_or_none<T>(opt: &mut Option<vector<T>>): Option<T> {
    //     if (option::is_none(opt)) {
    //         option::none()
    //     } else {
    //         option::some(vec::pop_back(option::borrow_mut(opt)))
    //     }
    // }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = COLLECTIBLE {};
        init(otw, ctx);
    }
}
