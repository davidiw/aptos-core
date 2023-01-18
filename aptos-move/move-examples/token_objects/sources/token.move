/// This defines an object-based Token. The key differentiating features from the Aptos standard
/// token are:
/// * Decouple token ownership from token data.
/// * Explicit data model for token metadata via adjacent resources
/// * Extensible framework for tokens
///
/// TODO:
/// * Provide functions for mutability -- the capability model seems to heavy for mutations, so
///   probably keep the existing model
/// * Consider adding an optional source name if name is mutated, since the objects address depends
///   on the name...
module token_objects::token {
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use std::vector;

    use aptos_framework::object::{Self, CreatorRef, ObjectId};

    use token_objects::collection::{Self, Royalty};

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Represents the common fields to all tokens.
    struct Token has key {
        /// An optional categorization of similar token, there are no constraints on collections.
        collection: String,
        /// The original creator of this token.
        creator: address,
        /// A brief description of the token.
        description: String,
        /// Determines which fields are mutable.
        mutability_config: MutabilityConfig,
        /// The name of the token, which should be unique within the collection; the length of name
        /// should be smaller than 128, characters, eg: "Aptos Animal #1234"
        name: String,
        /// The creation name of the token. Since tokens are created with the name as part of the
        /// object id generation.
        creation_name: Option<String>,
        /// The Uniform Resource Identifier (uri) pointing to the JSON file stored in off-chain
        /// storage; the URL length will likely need a maximum any suggestions?
        uri: String,
    }

    /// This config specifies which fields in the TokenData are mutable
    struct MutabilityConfig has copy, drop, store {
        description: bool,
        name: bool,
        uri: bool,
    }

    public fun create_token(
        creator: &signer,
        collection: String,
        description: String,
        mutability_config: MutabilityConfig,
        name: String,
        royalty: Option<Royalty>,
        uri: String,
    ): CreatorRef {
        let creator_address = signer::address_of(creator);
        let seed = derive_token_id_seed(&collection, &name);
        let creator_ref = object::create_named_object(creator, seed);
        let object_signer = object::generate_signer(&creator_ref);

        collection::increment_supply(&creator_address, &collection);
        move_to(
            &object_signer,
            Token {
                collection,
                creator: creator_address,
                description,
                mutability_config,
                name,
                creation_name: option::none(),
                uri,
            },
        );

        if (option::is_some(&royalty)) {
            collection::init_royalty(&object_signer, option::extract(&mut royalty))
        };
        creator_ref
    }

    public fun create_mutability_config(description: bool, name: bool, uri: bool): MutabilityConfig {
        MutabilityConfig { description, name, uri }
    }

    public fun derive_token_id(creator: &address, collection: &String, name: &String): ObjectId {
        object::derive_object_id(creator, derive_token_id_seed(collection, name))
    }

    public fun derive_token_id_seed(collection: &String, name: &String): vector<u8> {
        let seed = *string::bytes(collection);
        vector::append(&mut seed, b"::");
        vector::append(&mut seed, *string::bytes(name));
        seed
    }

    /// Simple token creation that generates a token and deposits it into the creators object store.
    public entry fun mint_token(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_name: bool,
        mutable_uri: bool,
        enable_royalty: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
        royalty_payee_address: address,
    ) {
        let mutability_config = create_mutability_config(
            mutable_description,
            mutable_name,
            mutable_uri,
        );

        let royalty = if (enable_royalty) {
            option::some(collection::create_royalty(
                royalty_numerator,
                royalty_denominator,
                royalty_payee_address,
            ))
        } else {
            option::none()
        };

        create_token(
            creator,
            collection,
            description,
            mutability_config,
            name,
            royalty,
            uri,
        );
    }

    // Accessors

    public fun creator(token_id: address): address acquires Token {
        let token = borrow_global<Token>(token_id);
        token.creator
    }

    // Mutators

    // Entry functions

    entry fun update_description(
        creator: &signer,
        collection: String,
        name: String,
        description: String
    )  acquires Token {
        let token_id = derive_token_id(&signer::address_of(creator), &collection, &name);
        let token = borrow_global_mut<Token>(object::object_id_address(&token_id));
        token.description = description;
    }

    #[test(creator = @0x123, trader = @0x456)]
    entry fun test_create_and_transfer(creator: &signer, trader: &signer) {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, *&collection_name, 1);
        create_token_helper(creator, *&collection_name, *&token_name);

        let creator_address = signer::address_of(creator);
        let token_id = derive_token_id(&creator_address, &collection_name, &token_name);
        assert!(object::owner(token_id) == creator_address, 1);
        object::transfer(creator, token_id, signer::address_of(trader));
        assert!(object::owner(token_id) == signer::address_of(trader), 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x20000, location = token_objects::collection)]
    entry fun test_too_many_tokens(creator: &signer) {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, *&collection_name, 1);
        create_token_helper(creator, *&collection_name, token_name);
        create_token_helper(creator, collection_name, string::utf8(b"bad"));
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x80000, location = aptos_framework::object)]
    entry fun test_duplicate_tokens(creator: &signer) {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, *&collection_name, 1);
        create_token_helper(creator, *&collection_name, *&token_name);
        create_token_helper(creator, collection_name, token_name);
    }

    #[test_only]
    entry fun create_collection_helper(creator: &signer, collection_name: String, max_supply: u64) {
        collection::create_collection(
            creator,
            string::utf8(b"collection description"),
            collection_name,
            string::utf8(b"collection uri"),
            false,
            false,
            max_supply,
            false,
            0,
            0,
            signer::address_of(creator),
        );
    }

    #[test_only]
    entry fun create_token_helper(creator: &signer, collection_name: String, token_name: String) {
        mint_token(
            creator,
            collection_name,
            string::utf8(b"token description"),
            token_name,
            string::utf8(b"token uri"),
            false,
            false,
            false,
            true,
            25,
            10000,
            signer::address_of(creator),
        );
    }
}
