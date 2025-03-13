#[test_only]
module nft::collectible_test {
    use nft::collectible::{
        Self as contract,
        Registry,
        CollectionTicket,
        Collection,
        CollectionCap,
        Collectible,
        Attribute
    };
    use std::{option::some, string::String};
    use sui::{
        test_scenario::{Self as scenario, Scenario},
        test_utils::{destroy, assert_eq},
        vec_map::VecMap
    };

    const Alice: address = @0x1abc;

    public struct COLLECTIBLE_TEST has drop {}

    public struct Meta has key, store {
        id: UID,
        cool: bool,
        animal: bool,
    }

    fun setup(): (Scenario, Registry, Collection<Meta>, CollectionCap<Meta>) {
        let mut scenario = scenario::begin(Alice);
        contract::test_init(scenario.ctx());
        scenario.next_tx(Alice);

        let registry = scenario.take_shared<Registry>();
        scenario.next_tx(Alice);

        let otw = COLLECTIBLE_TEST {};

        contract::claim_ticket<COLLECTIBLE_TEST, Meta>(otw, option::some(100), scenario.ctx());
        scenario.next_tx(Alice);

        let ticket = scenario.take_from_sender<CollectionTicket<Meta>>();

        let (collection, coll_cap) = setup_collection(&mut scenario, &registry, false, ticket);

        (scenario, registry, collection, coll_cap)
    }

    #[test]
    fun test_collection_getter_functions() {
        let (scen, registry, collection, coll_cap) = setup();

        let (burnable, burned_amount) = collection.get_burned();
        // bools and numbers
        assert_eq(collection.get_minted(), 0);
        assert_eq(burnable, true);
        assert_eq(burned_amount, 0);
        assert_eq(collection.is_dynamic(), false);
        assert_eq(collection.get_max_supply(), option::some(100));
        // Strings
        assert_eq(collection.get_creator(), b"Alice".to_string());
        assert_eq(collection.get_banner_url(), b"https://example.com/banner".to_string());
        assert_eq(
            collection.get_attribute_fields(),
            vector[
                b"Background".to_string(),
                b"Hat".to_string(),
                b"Shoes".to_string(),
                b"Jacket".to_string(),
            ],
        );
        // Id
        assert_eq(coll_cap.get_collection_id_by_cap(), object::id(&collection));

        destroy(collection);
        destroy(coll_cap);
        destroy(registry);
        scen.end();
    }

    #[test]
    fun test_create_attribute() {
        let (mut scen, registry, mut collection, coll_cap) = setup();

        let attribute = setup_attribute(&mut scen, &mut collection, &coll_cap);
        let image_url = attribute.get_attribute_image_url();
        let (key, value) = attribute.get_attribute_data();

        assert_eq(image_url, option::none());
        assert_eq(key, b"Background".to_string());
        assert_eq(value, b"red".to_string());

        destroy(attribute);
        destroy(collection);
        destroy(coll_cap);
        destroy(registry);
        scen.end();
    }

    #[test]
    fun test_create_collectible() {
        let (mut scen, registry, mut collection, coll_cap) = setup();

        let attribute = setup_attribute(&mut scen, &mut collection, &coll_cap);
        let attribute_id: ID = object::id(&attribute);
        let collectible = setup_static_collectible(
            &mut scen,
            &mut collection,
            some(vector[attribute]),
            &coll_cap,
        );

        let (has_attribute, map): (bool, VecMap<String, ID>) = collectible.get_attribute_map();
        let keys: vector<String> = map.keys();
        let attribute_value: &ID = map.get(&b"Background".to_string());
        let meta: &Option<Meta> = collectible.borrow_meta();
        let meta: &Meta = meta.borrow();

        assert_eq(meta.cool, true);
        assert_eq(meta.animal, false);

        assert!(attribute_id == attribute_value, 0);

        assert_eq(has_attribute, true);
        assert_eq(keys.contains(&b"Background".to_string()), true);
        assert_eq(collectible.get_name(), b"Name".to_string());
        assert_eq(collectible.get_image_url(), b"https://example.com/image".to_string());
        assert_eq(collectible.get_description(), b"Description".to_string());

        destroy(collectible);
        destroy(collection);
        destroy(coll_cap);
        destroy(registry);
        scen.end();
    }

    // #[test]
    // fun test_nft_with_mutiple_attributes() {
    //     let (mut scen, registry, mut collection, coll_cap) = setup();
    //     let mut i = 0;
    //     let mut attributes = vector::empty<Attribute<Meta>>();
    //     let keys = vector[b"Background".to_string(), b"Hat".to_string(), b"Shoes".to_string()];
    //     let values = vector[b"red".to_string(), b"fedora".to_string(), b"sneakers".to_string()];
    //     while (i < 4) {}
    // }

    // ================= Helper functions =================
    fun setup_collection(
        scenario: &mut Scenario,
        registry: &Registry,
        dynamic: bool,
        ticket: CollectionTicket<Meta>,
    ): (Collection<Meta>, CollectionCap<Meta>) {
        let banner_url = b"https://example.com/banner".to_string();
        let fields = vector[
            b"Background".to_string(),
            b"Hat".to_string(),
            b"Shoes".to_string(),
            b"Jacket".to_string(),
        ];

        let (collection, coll_cap) = ticket.create_collection(
            registry,
            banner_url,
            fields,
            option::some(b"Alice".to_string()),
            dynamic,
            true,
            scenario.ctx(),
        );

        (collection, coll_cap)
    }

    fun setup_static_collectible(
        scenario: &mut Scenario,
        collection: &mut Collection<Meta>,
        attribute: Option<vector<Attribute<Meta>>>,
        cap: &CollectionCap<Meta>,
    ): Collectible<Meta> {
        let name = b"Name".to_string();
        let description = b"Description".to_string();
        let image_url = b"https://example.com/image".to_string();
        let meta = Meta { id: object::new(scenario.ctx()), cool: true, animal: false };

        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(description),
            attribute,
            some(meta),
            scenario.ctx(),
        );
        nft
    }

    fun setup_attribute(
        scenario: &mut Scenario,
        collection: &mut Collection<Meta>,
        cap: &CollectionCap<Meta>,
    ): Attribute<Meta> {
        let image_url: Option<String> = option::none();
        let key = b"Background".to_string();
        let value = b"red".to_string();

        let attribute = collection.mint_attribute(cap, image_url, key, value, scenario.ctx());

        attribute
    }
}
