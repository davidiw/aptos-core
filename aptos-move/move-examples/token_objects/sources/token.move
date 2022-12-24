/// This defines an object-based Token. The key differentiating features from the Aptos standard
/// token are:
/// * Decouple token ownership from token data.
/// * Explicit data model for token metadata via adjacent resources
/// * Attempt at having cleaner semantic on capabilities surrounding tokens
///
/// TODO:
/// * Create the notion of a collection such that it can be used to guide creation of tokens
/// * Provide functions for mutability -- the capability model seems to heavy for mutations, so
///   probably keep the existing model
/// * Consider adding an optional source name if name is mutated, since the objects address depends
///   on the name...
module token_objects::token {
    // use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use std::vector;

    use aptos_framework::object::{Self, CreatorAbility};

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
        ///should be smaller than 128, characters, eg: "Aptos Animal #1234"
        name: String,
        /// The denominator and numerator for calculating the royalty fee; it also contains payee
        /// account address for depositing the Royalty
        royalty: Royalty,
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

    /// The royalty of a token
    struct Royalty has copy, drop, store {
        numerator: u64,
        denominator: u64,
        /// The recipient of royalty payments. See the `shared_account` for how to handle multiple
        /// creators.
        payee_address: address,
    }

    public fun create_token(
        creator: &signer,
        collection: String,
        description: String,
        mutability_config: MutabilityConfig,
        name: String,
        royalty: Royalty,
        uri: String,
    ): CreatorAbility {
        let seed = create_token_id_seed(&collection, &name);
        // To keep costs down, this function does not check to see if the object already exists
        let creator_ability = object::create_object(creator, seed);
        let signer_ability = object::generate_signer_ability(&creator_ability);
        let token_signer = object::create_signer(&signer_ability);

        let token = Token {
            collection,
            creator: signer::address_of(creator),
            description,
            mutability_config,
            name,
            royalty,
            uri,
        };

        move_to(&token_signer, token);
        creator_ability
    }

    public fun create_token_id(creator: &address, collection: &String, name: &String): address {
        object::create_object_id(creator, create_token_id_seed(collection, name))
    }

    public fun create_token_id_seed(collection: &String, name: &String): vector<u8> {
        let seed = *string::bytes(collection);
        vector::append(&mut seed, b"::");
        vector::append(&mut seed, *string::bytes(name));
        seed
    }

    public fun create_mutability_config(description: bool, name: bool, uri: bool): MutabilityConfig {
        MutabilityConfig {
            description,
            name,
            uri,
        }
    }

    public fun create_royalty(numerator: u64, denominator: u64, payee_address: address): Royalty {
        Royalty {
            numerator,
            denominator,
            payee_address,
        }
    }

    /// Simple token creation that generates a token and deposits it into the creators object store.
    entry fun mint_token(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_name: bool,
        mutable_uri: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
        royalty_payee_address: address,
    ) {
        let mutability_config = create_mutability_config(
            mutable_description,
            mutable_name,
            mutable_uri,
        );

        let royalty = create_royalty(
            royalty_numerator,
            royalty_denominator,
            royalty_payee_address,
        );

        let creator_ability = create_token(
            creator,
            collection,
            description,
            mutability_config,
            name,
            royalty,
            uri,
        );

        let owner_ability = object::generate_owner_ability(&creator_ability);
        object::deposit(creator, owner_ability);
    }

    #[test_only]
    use aptos_framework::account;

    #[test(creator = @0x123, trader = @0x456)]
    fun test_create_and_transfer(creator: &signer, trader: &signer) {
        let creator_addr = signer::address_of(creator);
        let collection = string::utf8(b"collection");
        let name = string::utf8(b"name");

        let token_id = create_token_id(&creator_addr, &collection, &name);

        account::create_account_for_test(creator_addr);
        object::init_store(creator);
        mint_token(
            creator,
            collection,
            string::utf8(b"description"),
            name,
            string::utf8(b"uri"),
            false,
            false,
            false,
            0,
            0,
            creator_addr,
        );

        let token = object::withdraw(creator, token_id);
        account::create_account_for_test(signer::address_of(trader));
        object::init_store(trader);
        object::deposit(trader, token);
    }
}
