// SPDX-License-Identifier: MIT

module nft::attributes {
    use nft::collectible::Collection;
    use std::string::{Self, String};
    use sui::event::emit;

    public struct Attribute<phantom T> has key, store {
        id: UID,
        image_url: Option<String>,
        key: String, // Background, Cloth, etc.
        value: String, // red-sky, jacket, etc.
    }

    // ============== Events ==============
    public struct AttributeMinted has copy, drop {
        collection_id: ID,
        attribute_id: ID,
        image_url: Option<String>,
        key: String,
        value: String,
    }

    public struct AttributeJoined has copy, drop {
        collectible_id: ID,
        attribute_id: ID,
    }

    public struct AttributeSplit has copy, drop {
        collectible_id: ID,
        attribute_id: ID,
    }

    public(package) fun new<T: store>(
        image_url: Option<String>,
        key: String,
        value: String,
        collection: ID,
        ctx: &mut TxContext,
    ): Attribute<T> {
        let attribute = Attribute<T> {
            id: object::new(ctx),
            image_url,
            key,
            value,
        };
        emit(AttributeMinted {
            collection_id: collection,
            attribute_id: object::id(&attribute),
            image_url,
            key,
            value,
        });
        attribute
    }

    public fun into_value<T: store>(self: &Attribute<T>): String {
        self.value
    }

    public fun into_key<T: store>(self: &Attribute<T>): String {
        self.key
    }

    public fun get_attribute_data<T: store>(attribute: &Attribute<T>): (String, String) {
        (attribute.key, attribute.value)
    }

    public fun get_attribute_image_url<T: store>(attribute: &Attribute<T>): Option<String> {
        attribute.image_url
    }

    public(package) fun emit_joined<T: store>(self: &Attribute<T>, collectible_id: ID) {
        emit(AttributeJoined {
            collectible_id,
            attribute_id: self.id.to_inner(),
        });
    }

    public(package) fun emit_split<T: store>(self: &Attribute<T>, collectible_id: ID) {
        emit(AttributeSplit {
            collectible_id,
            attribute_id: self.id.to_inner(),
        });
    }
}
