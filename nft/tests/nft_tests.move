// #[test_only]
// module nft::nft_tests {
//     use nft::nft::{Self as s_nft, Collection, Nft, OwnerCap};
//     use sui::{
//         package::{Publisher, claim},
//         test_scenario::{Self, ctx, Scenario},
//         test_utils::{destroy, assert_eq}
//     };
//
//     public struct NFT_TESTS has drop {}
//
//     const Alice: address = @0x1;
//
//     #[test]
//     fun test_create_collection() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let collection = prepare_collection(&mut scen, &publisher);
//         destroy(collection);
//
//         destroy(publisher);
//         scen.end();
//     }
//
//     #[test]
//     fun test_mint_nft() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft = prepare_nft(&mut scen, &mut collection, &owner_cap, true);
//
//         destroy(publisher);
//         destroy(nft);
//         destroy(collection);
//         destroy(owner_cap);
//
//         scen.end();
//     }
//
//     #[test]
//     fun test_create_validate_hash() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft = prepare_nft(&mut scen, &mut collection, &owner_cap, true);
//
//         let hash: vector<u8> = collection.create_attribute_hash(
//             vector[b"test_attribute_1".to_string()],
//             vector[b"test_value_1".to_string()],
//         );
//
//         let valid: bool = nft.validate_attribute(hash, vector[b"test_attribute_1".to_string()]);
//         assert_eq(valid, true);
//
//         destroy(publisher);
//         destroy(nft);
//         destroy(collection);
//         destroy(owner_cap);
//         scen.end();
//     }
//
//     #[test]
//     fun test_create_invalidate_hash() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft = prepare_nft(&mut scen, &mut collection, &owner_cap, true);
//
//         let hash: vector<u8> = collection.create_attribute_hash(
//             vector[b"test_attribute_1".to_string()],
//             vector[b"test_value_9".to_string()],
//         );
//
//         let valid: bool = nft.validate_attribute(hash, vector[b"test_attribute_1".to_string()]);
//         assert_eq(valid, false);
//
//         destroy(publisher);
//         destroy(nft);
//         destroy(collection);
//         destroy(owner_cap);
//         scen.end();
//     }
//
//     #[test]
//     fun test_burn_nft() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft: Nft<NFT_TESTS> = prepare_nft(&mut scen, &mut collection, &owner_cap, true);
//         nft.burn_nft(&mut collection, &owner_cap, scen.ctx());
//
//         destroy(publisher);
//         destroy(collection);
//         destroy(owner_cap);
//         scen.end();
//     }
//
//     // ================= Aborts =================
//
//     #[test, expected_failure(abort_code = s_nft::ENotBurnable)]
//     fun test_nft_not_burnable() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft: Nft<NFT_TESTS> = prepare_nft(&mut scen, &mut collection, &owner_cap, false);
//         nft.burn_nft(&mut collection, &owner_cap, scen.ctx());
//
//         destroy(publisher);
//         destroy(collection);
//         destroy(owner_cap);
//         scen.end();
//     }
//
//     #[test, expected_failure(abort_code = s_nft::EAttributeNotAllowed)]
//     fun test_attribute_not_allowed() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft: Nft<NFT_TESTS> = s_nft::mint_nft(
//             &mut collection,
//             b"Test name NFT".to_string(),
//             b"Test image_url NFT".to_string(),
//             b"Test desc NFT".to_string(),
//             true,
//             vector[b"wrong_attribute_1".to_string()],
//             vector[b"test_value_1".to_string()],
//             &owner_cap,
//             scen.ctx(),
//         );
//
//         destroy(publisher);
//         destroy(nft);
//         destroy(collection);
//         destroy(owner_cap);
//         scen.end();
//     }
//
//     #[test, expected_failure(abort_code = s_nft::ENotSameLength)]
//     fun test_attribute_not_same_length() {
//         let mut scen = test_scenario::begin(Alice);
//         let otw = NFT_TESTS {};
//         let publisher = claim(otw, scen.ctx());
//
//         let mut collection = prepare_collection(&mut scen, &publisher);
//         let owner_cap = scen.take_from_address<OwnerCap<NFT_TESTS>>(Alice);
//
//         let nft: Nft<NFT_TESTS> = s_nft::mint_nft(
//             &mut collection,
//             b"Test name NFT".to_string(),
//             b"Test image_url NFT".to_string(),
//             b"Test desc NFT".to_string(),
//             true,
//             vector[b"test_attribute_1".to_string(), b"test_attribute_2".to_string()],
//             vector[b"test_value_1".to_string()],
//             &owner_cap,
//             scen.ctx(),
//         );
//
//         destroy(publisher);
//         destroy(nft);
//         destroy(collection);
//         destroy(owner_cap);
//         scen.end();
//     }
//
//     #[test_only]
//     fun prepare_nft(
//         scen: &mut Scenario,
//         collection: &mut Collection<NFT_TESTS>,
//         owner_cap: &OwnerCap<NFT_TESTS>,
//         burnable: bool,
//     ): Nft<NFT_TESTS> {
//         s_nft::mint_nft(
//             collection,
//             b"Test name NFT".to_string(),
//             b"Test image_url NFT".to_string(),
//             b"Test desc NFT".to_string(),
//             burnable,
//             vector[b"test_attribute_1".to_string(), b"test_attribute_2".to_string()],
//             vector[b"test_value_1".to_string(), b"test_value_2".to_string()],
//             owner_cap,
//             scen.ctx(),
//         )
//     }
//
//     #[test_only]
//     fun prepare_collection(scen: &mut Scenario, publisher: &Publisher): Collection<NFT_TESTS> {
//         let name = b"Test Collection".to_string();
//         let image_url = b"test_image_url".to_string();
//         let banner_url = b"test_banner_url".to_string();
//         let desc = b"test_desc".to_string();
//         let project_url = b"test_project_url".to_string();
//         let creator = b"Alice".to_string();
//         let attribute_types = vector[
//             b"test_attribute_1".to_string(),
//             b"test_attribute_2".to_string(),
//         ];
//         s_nft::default<NFT_TESTS>(
//             publisher,
//             name,
//             image_url,
//             banner_url,
//             desc,
//             project_url,
//             creator,
//             attribute_types,
//             scen.ctx(),
//         );
//         scen.next_tx(Alice);
//
//         scen.take_shared<Collection<NFT_TESTS>>()
//     }
// }
