// SPDX-License-Identifier: MIT

module nft::collectible {
    use std::{hash::sha2_256, option::some, string::{Self, String}, vector as vec};
    use sui::{
        borrow::{Self, Referent, Borrow},
        display::{Self, Display},
        dynamic_object_field as dyn_field,
        event::emit,
        package::{Self, Publisher},
        transfer_policy::{Self as policy, TransferPolicyCap},
        tx_context::sender,
        vec_map::{Self as map, VecMap}
    };

    // ============== Error Codes ==============
    // Collections errors
    const ENotOneTimeWitness: u64 = 0;
    const ETypeNotFromModule: u64 = 1;
    const ECapReached: u64 = 2;
    const EVectorsNotEmpty: u64 = 3;
    const EWrongCollection: u64 = 4;
    const ENotDynamic: u64 = 10;
    // Collectibles errors
    // const ENotBurnable: u64 = 5;
    // const ENotAllCollectiblesBurned: u64 = 6;
    // Attributes errors
    const EDoesNotHaveAttributes: u64 = 7;
    const EAttributeNotAllowed: u64 = 9;
    const EAttributeTypeExists: u64 = 11;
    // General errors
    const ENotSameLength: u64 = 8;

    /// Centralized registry to provide access to system features of
    /// the Collectible.
    public struct Registry has key {
        id: UID,
        publisher: Publisher,
    }

    public struct Collection<T: store> has key, store {
        id: UID,
        // Stored objects
        publisher: Referent<Publisher>,
        display_collectible: Referent<Display<Collectible<T>>>,
        display_attribute: Referent<Display<Attribute<T>>>,
        policy_cap_collectible: Referent<TransferPolicyCap<Collectible<T>>>,
        policy_cap_attribute: Referent<TransferPolicyCap<Attribute<T>>>,
        // Data fields
        max_supply: Option<u32>,
        attribute_fields: vector<String>,
        banner_url: String,
        creator: Option<String>,
        minted: u32,
        burned: u32,
        // boolean fields
        // If true a CollectionCap exists and is not immutable
        owned: bool,
        // allows to burn collectibles
        burnable: bool,
        // allowes to use join_attribute and split_attribute functions
        dynamic: bool,
    }

    public struct CollectionCap<phantom T: store> has key, store {
        id: UID,
        collection: ID,
    }

    public struct CollectionTicket<phantom T: store> has key, store {
        id: UID,
        publisher: Publisher,
        max_supply: Option<u32>,
    }

    public struct Collectible<T: store> has key, store {
        id: UID,
        image_url: String,
        name: Option<String>,
        description: Option<String>,
        attributes: Option<VecMap<String, ID>>,
        meta: Option<T>,
    }

    public struct Attribute<phantom T> has key, store {
        id: UID,
        image_url: Option<String>,
        key: String, // Background, Cloth, etc.
        value: String, // red-sky, jacket, etc.
    }

    /// OTW to initialize the Registry and the base type.
    public struct COLLECTIBLE has drop {}

    // ===================== Events =====================

    public struct EventTicketClaimed has copy, drop {
        ticket_id: ID,
        creator: address,
    }

    public struct EventCollectionCreated has copy, drop {
        collection_id: ID,
        collection_cap_id: ID,
        max_supply: Option<u32>,
        creator: address,
        attributes_fields: vector<String>,
        banner_url: String,
        dynamic: bool,
        burnable: bool,
    }

    public struct EventCollectibleMinted has copy, drop {
        collection_id: ID,
        collectible_id: ID,
        image_url: String,
        name: Option<String>,
        description: Option<String>,
        attributes: Option<VecMap<String, ID>>,
    }

    public struct EventAttributeMinted has copy, drop {
        collection_id: ID,
        attribute_id: ID,
        image_url: Option<String>,
        key: String,
        value: String,
    }

    public struct EventAttributeJoined has copy, drop {
        collectible_id: ID,
        attribute_id: ID,
    }

    public struct EventAttributeSplit has copy, drop {
        collectible_id: ID,
        attribute_id: ID,
    }

    public struct EventRevokeOwnership has copy, drop {
        collection_id: ID,
        collection_cap_id: ID,
    }

    public struct EventDestroyCollectible has copy, drop {
        collection_id: ID,
        collectible_id: ID,
    }

    public struct EventEditMade has copy, drop {
        item_id: ID,
        edit_name: String,
        edit_value: String,
    }

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
        let ticket = CollectionTicket<T> {
            id: object::new(ctx),
            publisher,
            max_supply,
        };

        emit(EventTicketClaimed {
            ticket_id: object::id(&ticket),
            creator: sender(ctx),
        });

        transfer::transfer(ticket, ctx.sender());
    }

    #[allow(lint(share_owned))]
    public fun create_collection<T: store>(
        ticket: CollectionTicket<T>,
        registry: &Registry,
        banner_url: String,
        fields: vector<String>,
        creator: Option<String>,
        dynamic: bool,
        burnable: bool,
        ctx: &mut TxContext,
    ): (Collection<T>, CollectionCap<T>) {
        let CollectionTicket { id, publisher, max_supply } = ticket;
        object::delete(id);

        let display_collectible = display::new<Collectible<T>>(&registry.publisher, ctx);
        let display_attribute = display::new<Attribute<T>>(&registry.publisher, ctx);
        let (policy_collectible, policy_cap_collectible) = policy::new<Collectible<T>>(
            &registry.publisher,
            ctx,
        );
        let (policy_attribute, policy_cap_attribute) = policy::new<Attribute<T>>(
            &registry.publisher,
            ctx,
        );

        transfer::public_share_object(policy_collectible);
        transfer::public_share_object(policy_attribute);

        let collection = Collection<T> {
            id: object::new(ctx),
            display_collectible: borrow::new(display_collectible, ctx),
            display_attribute: borrow::new(display_attribute, ctx),
            policy_cap_collectible: borrow::new(policy_cap_collectible, ctx),
            policy_cap_attribute: borrow::new(policy_cap_attribute, ctx),
            publisher: borrow::new(publisher, ctx),
            max_supply,
            banner_url,
            attribute_fields: fields,
            creator,
            minted: 0,
            burned: 0,
            dynamic,
            burnable,
            owned: true,
        };

        let cap = CollectionCap<T> {
            id: object::new(ctx),
            collection: object::id(&collection),
        };

        emit(EventCollectionCreated {
            collection_id: object::id(&collection),
            collection_cap_id: object::id(&cap),
            max_supply,
            creator: sender(ctx),
            attributes_fields: fields,
            banner_url,
            dynamic,
            burnable,
        });
        (collection, cap)
    }

    // === Minting ===

    /// Mint a single Collectible specifying the fields.
    /// Can only be performed by the owner of the `CollectionCap`.
    public fun mint<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        name: Option<String>,
        image_url: String,
        description: Option<String>,
        attribute_item: Option<vector<Attribute<T>>>,
        meta: Option<T>,
        ctx: &mut TxContext,
    ): Collectible<T> {
        assert!(cap.collection == object::id(collection), EWrongCollection);
        assert!(
            option::is_none(&collection.max_supply) || *option::borrow(&collection.max_supply) > collection.minted,
            ECapReached,
        );
        collection.minted = collection.minted + 1;

        let mut item = Collectible {
            id: object::new(ctx),
            image_url,
            name,
            description,
            attributes: option::none(),
            meta,
        };

        if (attribute_item.is_some()) {
            let mut att_items: vector<Attribute<T>> = attribute_item.destroy_some();
            while (!vec::is_empty(&att_items)) {
                let attribute = vector::remove(&mut att_items, 0);
                item.internal_join_attribute<T>(collection, attribute);
            };
            assert!(vec::length(&att_items) == 0, EVectorsNotEmpty);
            vec::destroy_empty(att_items);
        } else {
            option::destroy_none(attribute_item);
        };

        emit(EventCollectibleMinted {
            collection_id: object::id(collection),
            collectible_id: object::id(&item),
            image_url,
            name,
            description,
            attributes: item.attributes,
        });

        item
    }

    public fun mint_attribute<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        image_url: Option<String>,
        key: String,
        value: String,
        ctx: &mut TxContext,
    ): Attribute<T> {
        assert!(cap.collection == object::id(collection), EWrongCollection);
        assert!(collection.attribute_fields.contains(&key), EAttributeNotAllowed);
        let attribute = Attribute {
            id: object::new(ctx),
            image_url,
            key,
            value,
        };

        emit(EventAttributeMinted {
            collection_id: object::id(collection),
            attribute_id: object::id(&attribute),
            image_url,
            key,
            value,
        });
        attribute
    }

    // =============== Attribute Functions ============
    // === Validations ===

    public fun join_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &mut Collection<T>,
        attribute: Attribute<T>,
        _: &mut TxContext,
    ) {
        assert!(collection.dynamic, ENotDynamic);
        collectible.internal_join_attribute<T>(collection, attribute);
    }

    public fun split_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &mut Collection<T>,
        key: String,
        _: &mut TxContext,
    ): Attribute<T> {
        assert!(collection.dynamic, ENotDynamic);
        collectible.internal_split_attribute<T>(collection, key)
    }

    public fun create_attribute_hash<T: store>(
        collection: &Collection<T>,
        keys: vector<String>,
        values: vector<String>,
    ): vector<u8> {
        assert!(vector::length(&keys) == vector::length(&values), ENotSameLength);
        assert!(collection.attribute_fields.length() != 0, EDoesNotHaveAttributes);
        let types = collection.attribute_fields;
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

    public fun validate_attribute<T: key + store>(
        collectible: &Collectible<T>,
        hashed_attribute: vector<u8>,
        keys: vector<String>,
    ): bool {
        let mut attribute_hash = vector<u8>[];

        let mut i = 0;
        while (i < vector::length(&keys)) {
            let attribute: &Attribute<T> = dyn_field::borrow<String, Attribute<T>>(
                &collectible.id,
                keys[i],
            );
            vector::append(&mut attribute_hash, string::into_bytes(attribute.value));
            i = i + 1;
        };
        sha2_256(attribute_hash) == hashed_attribute
    }

    // ================ Edit methods ==================
    public fun edit_banner<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        banner_url: String,
    ) {
        assert!(cap.collection == object::id(collection), EWrongCollection);
        collection.banner_url = banner_url;
        emit(EventEditMade {
            item_id: object::id(collection),
            edit_name: string::utf8(b"banner_url"),
            edit_value: banner_url,
        });
    }

    // ================ Borrowing methods ==================

    public fun borrow_mut_policy_cap_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (TransferPolicyCap<Collectible<T>>, Borrow) {
        borrow::borrow(&mut self.policy_cap_collectible)
    }

    public fun return_policy_cap_collectible<T: store>(
        self: &mut Collection<T>,
        cap: TransferPolicyCap<Collectible<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.policy_cap_collectible, cap, borrow)
    }

    public fun borrow_mut_policy_cap_attribute<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (TransferPolicyCap<Attribute<T>>, Borrow) {
        borrow::borrow(&mut self.policy_cap_attribute)
    }

    public fun return_policy_cap_attribute<T: store>(
        self: &mut Collection<T>,
        cap: TransferPolicyCap<Attribute<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.policy_cap_attribute, cap, borrow)
    }

    public fun borrow_mut_display_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Display<Collectible<T>>, Borrow) {
        borrow::borrow(&mut self.display_collectible)
    }

    /// Return the `Display` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_display_collectible<T: store>(
        self: &mut Collection<T>,
        display: Display<Collectible<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.display_collectible, display, borrow)
    }

    public fun borrow_mut_display_attribute<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Display<Attribute<T>>, Borrow) {
        borrow::borrow(&mut self.display_attribute)
    }

    /// Return the `Display` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_display_attribute<T: store>(
        self: &mut Collection<T>,
        display: Display<Attribute<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.display_attribute, display, borrow)
    }

    /// Take the `Publisher` from the `CollectionCap`.
    public fun borrow_mut_publisher<T: store>(
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

    public fun borrow_meta<T: store>(collectible: &Collectible<T>): &Option<T> {
        &collectible.meta
    }

    public fun borrow_mut_meta<T: store>(
        collectible: &mut Collectible<T>,
        _: &CollectionCap<T>,
    ): &mut Option<T> {
        &mut collectible.meta
    }

    // === Burn ===
    public fun destroy_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
        collectible: Collectible<T>,
        _: &mut TxContext,
    ): Option<T> {
        let Collectible<T> { id, meta, .. } = collectible;
        emit(EventDestroyCollectible {
            collection_id: object::id(self),
            collectible_id: id.to_inner(),
        });
        id.delete();
        self.burned = self.burned + 1;
        meta
    }

    //TODO: Implement this function

    // public fun burn_collection<T: store>(
    //     self: Collection<T>,
    //     policy: TransferPolicy<Collectible<T>>,
    //     cap: CollectionCap<T>,
    //     ctx: &mut TxContext,
    // ) {
    //     assert!(self.burnable, ENotBurnable);
    //     assert!(self.minted == self.burned, ENotAllCollectiblesBurned);
    //
    //     let Collection<T> { id, publisher, display, policy_cap, .. } = self;
    //     let publisher = borrow::destroy(publisher);
    //     let display: Display<Collectible<T>> = borrow::destroy(display);
    //     let policy_cap = borrow::destroy(policy_cap);
    //
    //     publisher.burn();
    //     let coin = policy::destroy_and_withdraw(policy, policy_cap, ctx);
    //     transfer::public_transfer(coin, sender(ctx));
    //     transfer::public_freeze_object(display);
    //     id.delete();
    //     let CollectionCap<T> { id: cap_id, .. } = cap;
    //     cap_id.delete();
    // }

    public fun revoke_ownership<T: store>(cap: CollectionCap<T>, collection: &mut Collection<T>) {
        assert!(cap.collection == object::id(collection), EWrongCollection);
        collection.owned = false;
        let CollectionCap<T> { id, .. } = cap;
        emit(EventRevokeOwnership {
            collection_id: object::id(collection),
            collection_cap_id: id.to_inner(),
        });
        id.delete();
    }

    // ================= View functions ========================
    // === Collection ===
    public fun get_max_supply<T: store>(collection: &Collection<T>): Option<u32> {
        collection.max_supply
    }

    public fun get_minted<T: store>(collection: &Collection<T>): u32 {
        collection.minted
    }

    public fun get_burned<T: store>(collection: &Collection<T>): (bool, u32) {
        (collection.burnable, collection.burned)
    }

    public fun get_banner_url<T: store>(collection: &Collection<T>): String {
        collection.banner_url
    }

    public fun get_attribute_fields<T: store>(collection: &Collection<T>): vector<String> {
        collection.attribute_fields
    }

    public fun is_dynamic<T: store>(collection: &Collection<T>): bool {
        collection.dynamic
    }

    public fun get_collection_id_by_cap<T: store>(cap: &CollectionCap<T>): ID {
        cap.collection
    }

    // === Collectible ===
    public fun get_image_url<T: store>(collectible: &Collectible<T>): String {
        collectible.image_url
    }

    public fun get_name<T: store>(collectible: &Collectible<T>): String {
        if (collectible.name.is_some()) {
            *option::borrow(&collectible.name)
        } else {
            string::utf8(b"")
        }
    }

    public fun get_description<T: store>(collectible: &Collectible<T>): String {
        if (collectible.description.is_some()) {
            *option::borrow(&collectible.description)
        } else {
            string::utf8(b"")
        }
    }

    public fun get_creator<T: store>(collection: &Collection<T>): String {
        if (collection.creator.is_some()) {
            *option::borrow(&collection.creator)
        } else {
            string::utf8(b"")
        }
    }

    public fun get_attribute_map<T: store>(
        collectible: &Collectible<T>,
    ): (bool, VecMap<String, ID>) {
        if (collectible.attributes.is_some()) {
            (true, *option::borrow(&collectible.attributes))
        } else {
            (false, map::empty())
        }
    }

    public fun get_attribute_data<T: store>(attribute: &Attribute<T>): (String, String) {
        (attribute.key, attribute.value)
    }

    public fun get_attribute_image_url<T: store>(attribute: &Attribute<T>): Option<String> {
        attribute.image_url
    }

    // ================= Internal =======================
    fun internal_join_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &Collection<T>,
        attribute: Attribute<T>,
    ) {
        assert!(collection.attribute_fields.contains(&attribute.key), EAttributeNotAllowed);
        assert!(!dyn_field::exists_(&collectible.id, attribute.key), EAttributeTypeExists);
        emit(EventAttributeJoined {
            collectible_id: object::id(collectible),
            attribute_id: attribute.id.to_inner(),
        });
        if (collectible.attributes.is_some()) {
            let attribute_map: &mut VecMap<String, ID> = collectible.attributes.borrow_mut();
            attribute_map.insert(attribute.key, attribute.id.to_inner());

            dyn_field::add(&mut collectible.id, attribute.key, attribute);
        } else {
            let mut new_map = map::empty();
            new_map.insert(attribute.key, attribute.id.to_inner());
            collectible.attributes = some(new_map);
            dyn_field::add(&mut collectible.id, attribute.key, attribute);
        };
    }

    fun internal_split_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &Collection<T>,
        key: String,
    ): Attribute<T> {
        assert!(collection.attribute_fields.contains(&key), EAttributeNotAllowed);
        assert!(dyn_field::exists_(&collectible.id, key), EAttributeTypeExists);

        let attribute_map: &mut VecMap<String, ID> = collectible.attributes.borrow_mut();
        let (_key_string, _id_value) = attribute_map.remove(&key);

        let attribute = dyn_field::remove(&mut collectible.id, key);
        emit(EventAttributeSplit {
            collectible_id: object::id(collectible),
            attribute_id: object::id(&attribute),
        });

        attribute
    }

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
