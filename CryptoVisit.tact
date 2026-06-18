import "@stdlib/deploy";

// ─── Messages ─────────────────────────────────────────────────────────────────

message(0x01) RegisterCafe {
    cafeId: Int as uint64;
    name:   String;
}

message(0x02) RemoveCafe {
    cafeId: Int as uint64;
}

message(0x03) ClaimVisit {
    cafeId: Int as uint64;
}

// ─── Structs ──────────────────────────────────────────────────────────────────

struct CafeData {
    name:        String;
    registered:  Bool;
    totalVisits: Int as uint64;
}

// ─── Contract ─────────────────────────────────────────────────────────────────

contract CryptoVisit with Deployable {

    // Owner
    owner: Address;

    // Token supply
    totalMinted:     Int as uint256 = 0;
    maxSupply:       Int as uint256 = 100_000_000; // 100M CVT
    tokensPerVisit:  Int as uint32  = 10;          // 10 CVT per visit
    cooldown:        Int as uint32  = 14400;        // 4 hours in seconds

    // Cafe registry: cafeId (uint64) → CafeData
    cafes: map<Int, CafeData>;

    // Token balances: user Address → balance
    balances: map<Address, Int as uint256>;

    // Visit tracking: visitKey (hash of addr+cafeId) → last claim timestamp
    lastClaim: map<Int, Int as uint64>;

    // ─── Init ───────────────────────────────────────────────────────────────

    init() {
        self.owner = sender();
    }

    // ─── Admin ──────────────────────────────────────────────────────────────

    receive(msg: RegisterCafe) {
        require(sender() == self.owner, "Not owner");
        require(self.cafes.get(msg.cafeId) == null, "Already registered");
        self.cafes.set(msg.cafeId, CafeData{
            name:        msg.name,
            registered:  true,
            totalVisits: 0
        });
    }

    receive(msg: RemoveCafe) {
        require(sender() == self.owner, "Not owner");
        let cafe: CafeData? = self.cafes.get(msg.cafeId);
        require(cafe != null, "Not registered");
        self.cafes.set(msg.cafeId, CafeData{
            name:        cafe!!.name,
            registered:  false,
            totalVisits: cafe!!.totalVisits
        });
    }

    // ─── Core: Claim Visit ──────────────────────────────────────────────────

    receive(msg: ClaimVisit) {
        // 1. Cafe must exist and be active
        let cafeOpt: CafeData? = self.cafes.get(msg.cafeId);
        require(cafeOpt != null, "Cafe not registered");
        let cafe: CafeData = cafeOpt!!;
        require(cafe.registered, "Cafe not active");

        // 2. Cooldown check
        let key: Int = self.visitKey(sender(), msg.cafeId);
        let last: Int? = self.lastClaim.get(key);
        if (last != null) {
            require(
                now() >= last!! + self.cooldown,
                "Too soon — wait 4 hours"
            );
        }

        // 3. Supply cap
        require(
            self.totalMinted + self.tokensPerVisit <= self.maxSupply,
            "Max supply reached"
        );

        // 4. Update state
        self.lastClaim.set(key, now());
        self.totalMinted = self.totalMinted + self.tokensPerVisit;

        let curBal: Int? = self.balances.get(sender());
        self.balances.set(
            sender(),
            (curBal == null ? 0 : curBal!!) + self.tokensPerVisit
        );

        // 5. Update cafe visit counter
        self.cafes.set(msg.cafeId, CafeData{
            name:        cafe.name,
            registered:  true,
            totalVisits: cafe.totalVisits + 1
        });
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get fun balance(addr: Address): Int {
        let bal: Int? = self.balances.get(addr);
        return bal == null ? 0 : bal!!;
    }

    get fun cafeInfo(cafeId: Int): CafeData? {
        return self.cafes.get(cafeId);
    }

    get fun cooldownRemaining(addr: Address, cafeId: Int): Int {
        let key: Int  = self.visitKey(addr, cafeId);
        let last: Int? = self.lastClaim.get(key);
        if (last == null) { return 0; }
        let unlock: Int = last!! + self.cooldown;
        if (now() >= unlock) { return 0; }
        return unlock - now();
    }

    get fun totalSupply(): Int { return self.totalMinted; }
    get fun maxSupplyCap(): Int { return self.maxSupply; }

    // ─── Internal ────────────────────────────────────────────────────────────

    fun visitKey(addr: Address, cafeId: Int): Int {
        // Hash of (address bytes ++ cafeId) as unique key per user+cafe pair
        return beginCell()
            .storeAddress(addr)
            .storeUint(cafeId, 64)
            .endCell()
            .hash();
    }
}
