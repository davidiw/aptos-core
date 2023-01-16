module token_objects::example {
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};

    use aptos_framework::object::{
        Self,
        CreatorRef,
        DeleteRef,
        OwnerRef,
        TypedOwnerRef,
    };

    use token_objects::token;

    const ENOT_A_HERO: u64 = 1;
    const ENOT_A_WEAPON: u64 = 2;
    const ENOT_A_GEM: u64 = 3;
    const ENOT_CREATOR: u64 = 4;

    struct OnChainConfig has key {
        collection: String,
        mutability_config: token::MutabilityConfig,
        royalty: token::Royalty,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Hero has key {
        armor: Option<TypedOwnerRef<Armor>>,
        gender: String,
        race: String,
        shield: Option<TypedOwnerRef<Shield>>,
        weapon: Option<TypedOwnerRef<Weapon>>,
        delete: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Armor has key {
        defense: u64,
        gem: Option<TypedOwnerRef<Gem>>,
        weight: u64,
        delete: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Gem has key {
        attack_modifier: u64,
        defense_modifier: u64,
        magic_attribute: String,
        delete: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Shield has key {
        defense: u64,
        gem: Option<TypedOwnerRef<Gem>>,
        weight: u64,
        delete: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Weapon has key {
        attack: u64,
        gem: Option<TypedOwnerRef<Gem>>,
        weapon_type: String,
        weight: u64,
        delete: DeleteRef,
    }

    fun init_module(account: &signer) {
        let on_chain_config = OnChainConfig {
            collection: string::utf8(b"Hero Quest!"),
            mutability_config: token::create_mutability_config(true, true, true),
            royalty: token::create_royalty(0, 0, signer::address_of(account)),
        };
        move_to(account, on_chain_config);
    }

    fun create_token(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
    ): CreatorRef acquires OnChainConfig {
        assert!(exists<OnChainConfig>(signer::address_of(creator)), 23);
        let on_chain_config = borrow_global<OnChainConfig>(signer::address_of(creator));
        token::create_token(
            creator,
            *&on_chain_config.collection,
            description,
            *&on_chain_config.mutability_config,
            name,
            *&on_chain_config.royalty,
            uri,
        )
    }

    public fun create_hero(
        creator: &signer,
        description: String,
        gender: String,
        name: String,
        race: String,
        uri: String,
    ): OwnerRef acquires OnChainConfig {
        let creator_ability = create_token(creator, description, name, uri);
        let signer_ability = object::generate_signer_ability(&creator_ability);
        let token_signer = object::create_signer(&signer_ability);

        let hero = Hero {
            armor: option::none(),
            gender,
            race,
            shield: option::none(),
            weapon: option::none(),
            delete: object::generate_delete_ability(&creator_ability),
        };
				move_to(&token_signer, hero);

				object::generate_owner_ability(&creator_ability)
    }

		public fun object_to_hero(
				untyped_hero: OwnerRef,
		): TypedOwnerRef<Hero> acquires Hero {
				let hero_id = object::owner_ability_address(&untyped_hero);
				assert!(exists<Hero>(hero_id), ENOT_A_HERO);
				let hero = borrow_global<Hero>(hero_id);
				object::to_typed_owner_ability(untyped_hero, hero)
		}

    public fun hero_equip_weapon(
				hero: &TypedOwnerRef<Hero>,
				weapon: TypedOwnerRef<Weapon>,
		) acquires Hero {
				let hero_data = borrow_global_mut<Hero>(object::typed_owner_ability_address(hero));
        option::fill(&mut hero_data.weapon, weapon);
    }

    public fun create_weapon(
        creator: &signer,
        attack: u64,
        description: String,
        name: String,
        uri: String,
        weapon_type: String,
        weight: u64,
    ): OwnerRef acquires OnChainConfig {
        let creator_ability = create_token(creator, description, name, uri);
        let signer_ability = object::generate_signer_ability(&creator_ability);
        let token_signer = object::create_signer(&signer_ability);

        let weapon = Weapon {
            attack,
            gem: option::none(),
            weapon_type,
            weight,
            delete: object::generate_delete_ability(&creator_ability),
        };
				move_to(&token_signer, weapon);

				object::generate_owner_ability(&creator_ability)
    }

		public fun object_to_weapon(
				untyped_weapon: OwnerRef,
		): TypedOwnerRef<Weapon> acquires Weapon {
				let weapon_id = object::owner_ability_address(&untyped_weapon);
				assert!(exists<Weapon>(weapon_id), ENOT_A_WEAPON);
				let weapon = borrow_global<Weapon>(weapon_id);
				object::to_typed_owner_ability(untyped_weapon, weapon)
		}

    public fun weapon_equip_gem(
				weapon: &TypedOwnerRef<Weapon>,
				gem: TypedOwnerRef<Gem>,
		) acquires Weapon {
				let weapon_data = borrow_global_mut<Weapon>(object::typed_owner_ability_address(weapon));
        option::fill(&mut weapon_data.gem, gem);
    }

    public fun create_gem(
        creator: &signer,
        attack_modifier: u64,
        defense_modifier: u64,
        description: String,
        magic_attribute: String,
        name: String,
        uri: String,
    ): OwnerRef acquires OnChainConfig {
        let creator_ability = create_token(creator, description, name, uri);
        let signer_ability = object::generate_signer_ability(&creator_ability);
        let token_signer = object::create_signer(&signer_ability);

        let gem = Gem {
            attack_modifier,
            defense_modifier,
            magic_attribute,
            delete: object::generate_delete_ability(&creator_ability),
        };

				move_to(&token_signer, gem);

				object::generate_owner_ability(&creator_ability)
    }

    entry fun mint_gem(
        creator: &signer,
        attack_modifier: u64,
        defense_modifier: u64,
        description: String,
        magic_attribute: String,
        name: String,
        uri: String,
    ) acquires OnChainConfig {
        let owner_ability = create_gem(
            creator,
            attack_modifier,
            defense_modifier,
            description,
            magic_attribute,
            name,
            uri,
        );
        object::deposit(creator, owner_ability);
    }

    public entry fun delete_gem(
        creator: &signer,
        gem_id: address,
    ) acquires Gem {
        assert!(token::get_creator(gem_id) == signer::address_of(creator), ENOT_CREATOR);
        let gem = move_from<Gem>(gem_id);
        let Gem {
            attack_modifier: _,
            defense_modifier: _,
            magic_attribute: _,
            delete: delete_ability,
        } = gem;
        token::delete(delete_ability);
    }

		public fun object_to_gem(
				untyped_gem: OwnerRef,
		): TypedOwnerRef<Gem> acquires Gem {
				let gem_id = object::owner_ability_address(&untyped_gem);
				assert!(exists<Gem>(gem_id), ENOT_A_WEAPON);
				let gem = borrow_global<Gem>(gem_id);
				object::to_typed_owner_ability(untyped_gem, gem)
		}

    #[test_only]
    use aptos_framework::account;

    #[test(account = @0x3)]
    fun test_hero_with_gem_weapon(account: &signer) acquires Hero, Gem, OnChainConfig, Weapon {
        account::create_account_for_test(signer::address_of(account));
        init_module(account);

        let hero = create_hero(
            account,
            string::utf8(b"The best hero ever!"),
            string::utf8(b"Male"),
            string::utf8(b"Wukong"),
            string::utf8(b"Monkey God"),
            string::utf8(b""),
        );

        let weapon = create_weapon(
            account,
            32,
            string::utf8(b"A magical staff!"),
            string::utf8(b"Ruyi Jingu Bang"),
            string::utf8(b""),
            string::utf8(b"staff"),
            15,
        );

        let gem = create_gem(
            account,
            32,
            32,
            string::utf8(b"Beautiful specimen!"),
            string::utf8(b"earth"),
            string::utf8(b"jade"),
            string::utf8(b""),
        );

        let weapon_addr = object::owner_ability_address(&weapon);
        let gem_addr = object::owner_ability_address(&gem);

        object::init_store(account);
        object::deposit(account, weapon);
        object::deposit(account, gem);

        let untyped_weapon = object::withdraw(account, weapon_addr);
        let untyped_gem = object::withdraw(account, gem_addr);
        let weapon = object_to_weapon(untyped_weapon);

        weapon_equip_gem(&weapon, object_to_gem(untyped_gem));
        object::deposit_typed(account, weapon);

        let untyped_weapon = object::withdraw(account, weapon_addr);
        let hero = object_to_hero(hero);
        hero_equip_weapon(&hero, object_to_weapon(untyped_weapon));

        object::deposit_typed(account, hero);
    }

    #[test(account = @0x3)]
    fun test_create_delete_gem(account: &signer) acquires Gem, OnChainConfig {
        account::create_account_for_test(signer::address_of(account));
        init_module(account);
        object::init_store(account);

        mint_gem(
            account,
            32,
            32,
            string::utf8(b"Beautiful specimen!"),
            string::utf8(b"earth"),
            string::utf8(b"jade"),
            string::utf8(b""),
        );

        let gem_id = token::create_token_id(
            &signer::address_of(account),
            &string::utf8(b"Hero Quest!"),
            &string::utf8(b"jade"),
        );

        assert!(exists<Gem>(gem_id), 0);

        delete_gem(account, gem_id);
        assert!(!exists<Gem>(gem_id), 1);
    }
}
