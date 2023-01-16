// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_success, tests::common, MoveHarness};
use aptos_types::account_address::{self, AccountAddress};
use move_core_types::{identifier::Identifier, language_storage::StructTag};
use serde::Deserialize;

#[derive(Debug, Deserialize, Eq, PartialEq)]
struct Token {
    collection: String,
    creator: AccountAddress,
    description: String,
    mutability_config: MutabilityConfig,
    name: String,
    royalty: Royalty,
    uri: String,
}

#[derive(Debug, Deserialize, Eq, PartialEq)]
struct MutabilityConfig {
    description: bool,
    name: bool,
    uri: bool,
}

#[derive(Debug, Deserialize, Eq, PartialEq)]
struct Royalty {
    numerator: u64,
    denominator: u64,
    payee_address: AccountAddress,
}

#[derive(Debug, Deserialize, Eq, PartialEq)]
struct Object {
    guid_creation_num: u64,
}

#[test]
fn test_basic_token() {
    let mut h = MoveHarness::new();

    let addr = AccountAddress::from_hex_literal("0xcafe").unwrap();
    let account = h.new_account_at(addr);

    let mut build_options = aptos_framework::BuildOptions::default();
    build_options
        .named_addresses
        .insert("token_objects".to_string(), addr);

    let result = h.publish_package_with_options(
        &account,
        &common::test_dir_path("../../../move-examples/token_objects"),
        build_options,
    );
    assert_success!(result);

    let result = h.run_entry_function(
        &account,
        str::parse("0x1::object::init_store").unwrap(),
        vec![],
        vec![],
    );
    assert_success!(result);

    let result = h.run_entry_function(
        &account,
        str::parse(&format!("0x{}::example::mint_gem", addr)).unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<u64>(&32).unwrap(),
            bcs::to_bytes::<u64>(&32).unwrap(),
            bcs::to_bytes("Beautiful specimen!").unwrap(),
            bcs::to_bytes("earth").unwrap(),
            bcs::to_bytes("jade").unwrap(),
            bcs::to_bytes("404").unwrap(),
        ],
    );
    assert_success!(result);

    let token_id = account_address::create_token_id(addr, "Hero Quest!", "jade");
    let obj_tag = StructTag {
        address: AccountAddress::from_hex_literal("0x1").unwrap(),
        module: Identifier::new("object").unwrap(),
        name: Identifier::new("Object").unwrap(),
        type_params: vec![],
    };
    let token_obj_tag = StructTag {
        address: addr,
        module: Identifier::new("token").unwrap(),
        name: Identifier::new("Token").unwrap(),
        type_params: vec![],
    };
    let obj_group_tag = StructTag {
        address: AccountAddress::from_hex_literal("0x1").unwrap(),
        module: Identifier::new("object").unwrap(),
        name: Identifier::new("ObjectGroup").unwrap(),
        type_params: vec![],
    };

    // Ensure that the group data can be read
    let object_0: Object = h
        .read_resource_from_resource_group(&token_id, obj_group_tag.clone(), obj_tag.clone())
        .unwrap();
    let token_0: Token = h
        .read_resource_from_resource_group(&token_id, obj_group_tag.clone(), token_obj_tag.clone())
        .unwrap();
    // Ensure that the original resources cannot be read
    assert!(h.read_resource_raw(&token_id, obj_tag.clone()).is_none());
    assert!(h
        .read_resource_raw(&token_id, token_obj_tag.clone())
        .is_none());

    let result = h.run_entry_function(
        &account,
        str::parse(&format!("0x{}::token::update_description", addr)).unwrap(),
        vec![],
        vec![
            bcs::to_bytes("Hero Quest!").unwrap(),
            bcs::to_bytes("jade").unwrap(),
            bcs::to_bytes("Heck no!").unwrap(),
        ],
    );
    assert_success!(result);

    // verify all the data remains in a group even when updating just a single resource
    let object_1: Object = h
        .read_resource_from_resource_group(&token_id, obj_group_tag.clone(), obj_tag)
        .unwrap();
    let mut token_1: Token = h
        .read_resource_from_resource_group(&token_id, obj_group_tag.clone(), token_obj_tag)
        .unwrap();
    assert_eq!(object_0, object_1);
    assert_ne!(token_0, token_1);
    // Determine that the only difference is the mutated description
    assert_eq!(token_1.description, "Heck no!");
    token_1.description = "Beautiful specimen!".to_string();
    assert_eq!(token_0, token_1);

    // verify deletions are complete
    assert!(h
        .read_resource_group(&token_id, obj_group_tag.clone())
        .is_some());
    let result = h.run_entry_function(
        &account,
        str::parse(&format!("0x{}::example::delete_gem", addr)).unwrap(),
        vec![],
        vec![bcs::to_bytes(&token_id).unwrap()],
    );
    assert_success!(result);

    assert!(h.read_resource_group(&token_id, obj_group_tag).is_none());
}
