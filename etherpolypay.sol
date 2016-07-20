library LibCLLi {
/* Constants */

    uint constant NULL = 0;
    uint constant HEAD = NULL; // Lists are circular with static head.
    bool constant PREV = false; // Toward first in
    bool constant NEXT = true; // Away from first in
    
/* Structs */

    // Generic double linked list node.
    struct DoubleLinkNode {
        uint dataIndex; // not used if data elements are unique unless manually updated.
        mapping (bool => uint) links;
    }
    
    // Generic circular linked list parameters. Head is static index 0.
    struct LinkedList {
        uint64 size;  // Number of nodes
        uint64 newNodeKey; // Next free mapping slot
        bool uniqueData; // will save a sstore by using data as key if true
        uint auxData; // auxilary data state variable.
        mapping (uint => DoubleLinkNode) nodes;
    }

/* Functions */
	
    // Initialises circular linked list to a valid state
    function init(LinkedList storage self, bool _uniqueData) 
        internal returns (bool)
    {
        if (self.newNodeKey != NULL) return false;
        self.newNodeKey = 1; // can be used for list existence testing
        self.uniqueData = _uniqueData;
        return true;
    }

    function reset(LinkedList storage self)
        internal returns (bool)
    {
        self.newNodeKey = 1; // can be used for list existence testing
        self.nodes[HEAD].links[NEXT] = NULL; // reseting existing
        self.nodes[HEAD].links[PREV] = NULL; // reseting existing
        self.size = 0;
        return true;
    }

    function stitch(LinkedList storage self, uint a, uint b, bool _dir)
    	internal
    {
     	self.nodes[a].links[_dir] = b;
    	self.nodes[b].links[!_dir] = a;
    }
	
    function update(LinkedList storage self, uint _nodeKey, uint _dataIndex)
        internal returns (uint)
    {
        self.nodes[_nodeKey].dataIndex = _dataIndex;
        return _nodeKey;
    }
	
	/// @dev If the list is a set the data index is used as the node key
    function newNode(LinkedList storage self, uint _dataIndex)
        internal returns (uint nodeKey_)
    {
        nodeKey_ = _dataIndex;
        if (!self.uniqueData) {
            nodeKey_ = self.newNodeKey++;
            self.nodes[nodeKey_].dataIndex = _dataIndex;
        }
        self.size++;
        return nodeKey_;
    }

    /// _dir == false  Inserts new node BEFORE _nodeKey
    /// _dir == true   Inserts new node AFTER _nodeKey
    function insert (LinkedList storage self, uint a, uint b, bool _dir)
        internal returns (uint)
    {
        uint c = self.nodes[a].links[_dir];
        stitch (self, a, b, _dir);
        stitch (self, b, c, _dir);
        return b;
    }

    function insertNewNode(
        LinkedList storage self,
        uint _nodeKey,
        uint _dataIndex,
        bool _dir
    )
        internal returns (uint)
    {
        uint newKey = newNode(self, _dataIndex);
        return insert(self, _nodeKey, newKey, _dir);
    }
           
    function remove(LinkedList storage self, uint _nodeKey)
        internal returns (uint dataIndex_)
    {
        if (_nodeKey == NULL) return;
        dataIndex_ = _nodeKey; 
        if (!self.uniqueData) dataIndex_ = self.nodes[_nodeKey].dataIndex;
        uint a = self.nodes[_nodeKey].links[PREV];
        uint b = self.nodes[_nodeKey].links[NEXT];
        stitch(self, a, b, NEXT);
        self.size--;
        // Explicit deletes for mapping elements
        delete self.nodes[_nodeKey].links[PREV];
        delete self.nodes[_nodeKey].links[NEXT];
        delete self.nodes[_nodeKey].dataIndex;
        return;
    }

    function getNode(LinkedList storage self, uint _nodeKey)
        internal constant returns (uint[3])
    {
        return [
            self.nodes[_nodeKey].dataIndex,
            self.nodes[_nodeKey].links[PREV],
            self.nodes[_nodeKey].links[NEXT]];
    }

    function indexExists(LinkedList storage self, uint _nodeKey)
        internal constant returns (bool)
    {
        if (self.newNodeKey > 0) return true;
    }

    function step(LinkedList storage self, uint _nodeKey, bool _dir)
        internal constant returns (uint)
    {
        return self.nodes[_nodeKey].links[_dir];
    }

	// FILO storage
    function push(LinkedList storage self, uint _num)
        internal
        returns (uint)
    {
        return insertNewNode(self, HEAD, _num, NEXT);
    }

    function pop(LinkedList storage self) internal returns (uint)
    {
        return remove(self, step(self, HEAD, NEXT));
    }

	// FIFO storage
    function pushTail(LinkedList storage self, uint _num)
        internal 
        returns (uint)
    {
        return insertNewNode(self, HEAD, _num, PREV);
    }

    function popTail(LinkedList storage self) internal returns (uint)
    {
        return remove(self, step(self, HEAD, PREV));
    }
}


contract Misc
{

/* Constants */

    uint constant NULL = 0;
    bool constant LT = false;
    bool constant GT = true;

/* Modifiers */

    // To throw call not made by owner
    modifier isOwner() {
        // if (msg.sender != owner) throw;
        _
    }
	
    address public owner;

	// Prevents a function from accepting sent ether
	modifier noEther(){
		if (msg.value > 0) throw;
		_
	}

    // To lock a contracts mutex protected functions from entry if it or another
	// protected function has not yet returned.
	// Protected functions must have only one point of exit.
	// Protected functions cannot use the `return` keyword
	// Protected functions return values must be through return parameters.
    modifier mutexProtected() {
        if (mutex) throw;
        else mutex = true;
        _
        mutex = false;
        return;
    }

    /// @returns Entry state.
    bool public mutex;

/* Functions */

	// Parametric comparitor for > or <
    // !_dir Tests a < b
    // _dir  Tests a > b
    function cmp (uint a, uint b, bool _dir)
    	public
        constant
        returns (bool)
    {
        if (_dir) return a > b;
        else return a < b;
    }

	// Parametric comparitor for >= or <=
    // !_dir Tests a <= b
    // _dir  Tests a >= b
     function cmpEq (uint a, uint b, bool _dir)
    	public
        constant
        returns (bool)
    {
        return (a==b) || ((a < b) != _dir);
    }

	function changeOwner(address _newOwner)
		public
		mutexProtected
		isOwner {
		owner = _newOwner;
	}
}


contract EIP20Interface
{
    /* Structs */
        
    /* Constants */

    /* State Valiables */
    uint public totalSupply;
    uint8 public decimalPlaces;
    string public symbol;
    mapping (address => uint) public balances;
    mapping (address => mapping (address => uint)) public allowances;

/* State variable Accessor Functions (leave commented)

	function balances(address tokenHolder) public returns (uint);
	function allowanaces (address tokenHolders, address proxy, uint allowance) public returns (uint);
	function totalSupply() public returns (uint);
	function symbol() public returns(string);
	function decimalPlaces() public returns(uint);
*/

/* Function Abstracts */
	
    // Get the account balance of another account with address _owner
    function balanceOf(address _owner)
        public constant returns (uint256 balance);

    // Send _value amount of tokens to address _to
    function transfer(address _to, uint256 _value) public returns (bool success);

    // Send _value amount of tokens from address _from to address _to
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    // Allow _spender to withdraw from your account, multiple times, up to the _value amount. If this function is called again it overwrites the current allowance with _value.
    function approve(address _spender, uint256 _value) public returns (bool success);

    // Triggered when tokens are transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    // Triggered whenever approve(address _spender, uint256 _value) is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract EIP20Token is EIP20Interface, Misc
{
/* Constants */

/* Structs */
        
/* State Valiables */

/* Events */
	
/* Modifiers */
	
	modifier isAvailable(uint _amount) {
		if (_amount < balances[msg.sender]) throw;
		_
	}
	
	modifier hasAllowance(address _from, uint _amount) {
		if (_amount > allowances[_from][msg.sender] ||
		   _amount > balances[_from]) throw;
		_
	}

/* Funtions Public */
 
    // Get the account balance of another account with address _owner
    function balanceOf(address _holder)
        public constant returns (uint256 balance)
    {
        return balances[_holder];
    }

    // Send _value amount of tokens to address _to
    function transfer(address _to, uint256 _value)
		public
        mutexProtected()
		isAvailable(_value)
		returns (bool success_)
    {
        if (balances[msg.sender] < _value) throw;
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        success_ = true;
    }


    // Send _value amount of tokens from address _from to address _to
    function transferFrom(address _from, address _to, uint256 _value)
		public
        mutexProtected
        hasAllowance(_from, _value)
        returns (bool success_)
    {
        balances[_from] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        success_ = true;
    }

    // Allow _spender to withdraw from your account, multiple times, up to the _value amount. If this function is called again it overwrites the current allowance with _value.
    function approve(address _spender, uint256 _value)
		public
        mutexProtected
		returns (bool success_)        
    {
        if (balances[msg.sender] == 0) throw;
        allowances[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        success_ = true;
    }

}


contract ITTInterface
{
    using LibCLLi for LibCLLi.LinkedList;

/* Constants */

    uint constant PRICE_BOOK = 0;
	uint constant HEAD = 0;
    uint constant MINNUM = 1;
    uint constant MAXNUM = 2**128;
	bool constant PREV = false;
	bool constant NEXT = true;
    bool constant BID = false;
    bool constant ASK = true;
    uint constant MAXDEPTH = 100000; // remaning gas required to prevent out of gas on take recursion

    struct Order {
        // Price and swap are determined by FIFO price
        uint amount; // Token amount of Ask or ether Value of Bid. 
        address trader; // Token holder address
    }

    struct TradeMessage {
        uint amount;
        uint value;
        uint price;
        uint spent;
        uint bought;
        uint sold;
        uint orderId;
        bool swap;
        bool make;
    }
        
/* State Valiables */

    // Orders in order of creation
    Order[] public orders;


    LibCLLi.LinkedList public priceBook;
    mapping (uint => LibCLLi.LinkedList) public orderFIFOs;

    // Token holder accounts
    mapping (address => uint) public etherBalances;

/* Events */

    event Ask (uint indexed price, uint amount, uint indexed orderId, address indexed trader);
    event Bid (uint indexed price, uint amount, uint indexed orderId, address indexed trader);
    event Bought (uint indexed price, uint amount, uint indexed orderId, address seller, address indexed buyer);
    event Sold (uint indexed price, uint amount, uint indexed orderId, address indexed seller, address buyer);


/* Functions getters */
    function getMetrics()
		public constant returns (
            uint balance_,
            uint etherBalance_,
            uint lowestAsk_,
            uint highestBid_,
            uint askVol_,
            uint bidVol_,
            uint8 decimalPlaces_,
            string symbol_);

    function getVolumeAtPrice(uint _price)
        public constant returns (uint);
    
    function getFirstOrderIdAtPrice(uint _price)
        public constant returns(uint);
   
    function spread(bool _dir)
        public constant returns(uint);

/* Functions Public */

    function buy (uint _bidPrice, uint _amount, bool _make)
        public returns (bool success_);

    function sell (uint _askPrice, uint _amount, bool _make)
        public returns (bool success_);
 
    function withdraw(uint _ether)
        public returns (bool success_);

    function cancel(uint _price, uint _orderId)
        public returns (bool success_);
}


/* Intrinsically Tradable Token code */ 
contract ITT is Misc, ITTInterface, EIP20Token
{
    
/* Structs */

/* Modifiers */

    modifier isValidBuy(uint _bidPrice, uint _amount) {
        if ((etherBalances[msg.sender] + msg.value) < (_amount * _bidPrice) ||
            (_amount * _bidPrice ) == NULL) throw; // has insufficient ether.
        _
    }

    modifier isValidSell(uint _askPrice, uint _amount) {
        if (_amount > balances[msg.sender] ||
            (_amount * _askPrice ) == NULL) throw;
        _
    }

    modifier ownsOrder(uint _orderId) {
        if (msg.sender != orders[_orderId].trader) throw;
        _       
    }
    
    modifier hasEther(address _member, uint _ether) {
        if (etherBalances[_member] < _ether) throw;
        _
    }

    modifier hasBalance(address _member, uint _amount) {
        if (balances[_member] < _amount) throw;
        _
    }
    
    modifier limitRecurse() {
        if (msg.gas < MAXDEPTH) return;
        _
    }

        // !_dir Tests a < b
        // _dir  Tests a > b
    modifier takeAvailable(TradeMessage tmsg) {
        if (cmp(tmsg.price, spread(!tmsg.swap), tmsg.swap)) return;
        _
    }
	
	modifier isMake(TradeMessage tmsg) {
		if (!tmsg.make) {
			tmsg.amount = 0;
			return;
		}
		_
	}
	    
/* Functions */

    function ITT(uint _totalSupply, uint8 _decimalPlaces, string _symbol, address _owner)
//    function ITT()
    {
        totalSupply = _totalSupply;
        decimalPlaces = _decimalPlaces;
        symbol = _symbol;
        
        // setup pricebook and maximum spread.10
        priceBook.init(true);
        priceBook.nodes[HEAD].dataIndex = MINNUM;
        priceBook.nodes[HEAD].links[PREV] = MINNUM;
        priceBook.nodes[HEAD].links[NEXT] = MAXNUM;

        priceBook.nodes[MAXNUM].dataIndex = MAXNUM;
        priceBook.nodes[MAXNUM].links[PREV] = HEAD;
        priceBook.nodes[MAXNUM].links[NEXT] = MAXNUM;

        priceBook.nodes[MINNUM].dataIndex = MINNUM;
        priceBook.nodes[MINNUM].links[PREV] = MINNUM;
        priceBook.nodes[MINNUM].links[NEXT] = HEAD;
        
        // dummy order at index 0 to allow for order existance testing
        orders.push(Order(1,0));
    }
    
    function () 
    { 
        throw;
    }

/* Functions Getters */

    function getMetrics()
		public constant returns (
            uint balance_,
            uint etherBalance_,
            uint lowestAsk_,
            uint highestBid_,
            uint askVol_,
            uint bidVol_,
            uint8 decimalPlaces_,
            string symbol_)
   {
        balance_ = balances[msg.sender];
        etherBalance_ = etherBalances[msg.sender];
        lowestAsk_ = spread(ASK);
        highestBid_ = spread(BID);
        askVol_ = orderFIFOs[lowestAsk_].auxData;
        bidVol_ = orderFIFOs[highestBid_].auxData;
		decimalPlaces_ = decimalPlaces;
		symbol_ = symbol;
        return;
    }
    
    function getVolumeAtPrice(uint _price) public
        constant
        returns (uint)
    {
        return orderFIFOs[_price].auxData;
    }
    
    function getFirstOrderIdAtPrice(uint _price) public
        constant
        returns(uint)
    {
        return orderFIFOs[_price].step(HEAD, true);
    }
    
    function spread(bool _dir) public
        constant
        returns(uint)
    {
		return priceBook.step(HEAD, _dir);
    }
	
	function getNode(uint _list, uint _node)
		constant
		returns(uint[3])
	{
		if (_list == 0) return [
			priceBook.nodes[_node].links[PREV],
			priceBook.nodes[_node].links[NEXT],
			priceBook.nodes[_node].dataIndex];
		else return [
			orderFIFOs[_list].nodes[_node].links[PREV],
		 	orderFIFOs[_list].nodes[_node].links[NEXT],
			orderFIFOs[_list].nodes[_node].dataIndex];
	}

    function toPrice (uint _value, uint _amount) public
        constant
        returns (uint)
    {
        return _value / _amount;
    }

    function toAmount (uint _value, uint _price) public
        constant
        returns (uint)
    {
        return _value / _price;
    }

    function toValue (uint _price, uint _amount) public
        constant
        returns (uint)
    {
        return _price * _amount;
    }

/* Functions Public */

    function buy (uint _bidPrice, uint _amount, bool _make)
        public
        mutexProtected
        returns (bool success_)
    {
        buyIntl(_bidPrice, _amount, _make);
        success_ = true;
    }

    function sell (uint _askPrice, uint _amount, bool _make)
        public
        mutexProtected
        returns (bool success_)
    {
        sellIntl(_askPrice, _amount, _make);
        success_ = true;
    }

    function withdraw(uint _ether)
		public
        mutexProtected
        hasEther(msg.sender, _ether)
        returns (bool success_)
    {
        etherBalances[msg.sender] -= _ether;
        if(!msg.sender.send(_ether)) throw;
        success_ = true;
    }

    function cancel(uint _price, uint _orderId)
		public
        mutexProtected
        ownsOrder(_orderId)
        returns (bool success_)
    {
        if (_price > spread(BID))
            etherBalances[msg.sender] += toValue(_price, orders[_orderId].amount);
        else
            balances[msg.sender] += orders[_orderId].amount;
        closeOrder(_price, _orderId);
        success_ = true;
    }

/* Functions Internal */

    function buyIntl (uint _bidPrice, uint _amount, bool _make)
        internal
        isValidBuy(_bidPrice, _amount)
    {
        TradeMessage memory tmsg;
        tmsg.amount = _amount;
        tmsg.value = toValue(_bidPrice, _amount);
        tmsg.price = _bidPrice;
        tmsg.swap = BID;
        tmsg.make = _make;

        takeAsks(tmsg);
        makeBid(tmsg);

        balances[msg.sender] += tmsg.bought;
        etherBalances[msg.sender] += msg.value - tmsg.spent;
    }

    function sellIntl (uint _askPrice, uint _amount, bool _make)
        internal
        isValidSell(_askPrice, _amount)
    {
        TradeMessage memory tmsg;
        tmsg.amount = _amount;
        tmsg.price = _askPrice;
        tmsg.swap = ASK;
        tmsg.make = _make;

        takeBids(tmsg);
        makeAsk(tmsg);

        balances[msg.sender] += tmsg.amount - tmsg.sold;
        etherBalances[msg.sender] += tmsg.value;
    }

    function takeAsks(TradeMessage tmsg)
        // * NOTE * This function can recurse by design.
        internal
        limitRecurse
        takeAvailable(tmsg)
    {
        uint bestPrice = spread(!tmsg.swap);
        tmsg.orderId = getFirstOrderIdAtPrice(bestPrice);
        Order order = orders[tmsg.orderId];
        uint orderValue = toValue(bestPrice, order.amount);
        if (tmsg.amount >= order.amount) {
            // Take full amount
            tmsg.spent += orderValue;
            tmsg.bought += order.amount;
            tmsg.amount -= order.amount;
            etherBalances[order.trader] += orderValue;
            Bought (tmsg.price, order.amount, tmsg.orderId, order.trader, msg.sender);
            closeOrder(bestPrice, tmsg.orderId);
            takeAsks(tmsg); // recurse
            return;
        }
        if (tmsg.amount == 0) return;
        // Insufficient funds, take partial ask.
        order.amount -= tmsg.amount;
        tmsg.bought += tmsg.amount;
        etherBalances[order.trader] += toValue(bestPrice, tmsg.amount);
        orderFIFOs[bestPrice].auxData -= tmsg.amount;
        tmsg.spent += toValue(bestPrice, tmsg.amount);
        Bought (tmsg.price, tmsg.amount, tmsg.orderId, order.trader, msg.sender);
        tmsg.amount = 0;
        return;
}

    function takeBids(TradeMessage tmsg)
        // * NOTE * This function can recurse by design.
        internal
        limitRecurse
        takeAvailable(tmsg)
    {
        uint bestPrice = spread(!tmsg.swap);
        tmsg.orderId = getFirstOrderIdAtPrice(bestPrice);
        Order order = orders[tmsg.orderId];
        uint orderValue = toValue(bestPrice, order.amount);
        if (tmsg.amount >= order.amount) {
            // Take full amount 
			tmsg.value += toValue(bestPrice, order.amount);
            tmsg.amount -= order.amount;
            balances[order.trader] += order.amount;
            tmsg.sold += order.amount;
            Sold (bestPrice, order.amount, tmsg.orderId, msg.sender, order.trader);
            closeOrder(bestPrice, tmsg.orderId);
            takeBids(tmsg); // recurse;
            return;
        }
        if(tmsg.amount == 0) return;
        // Insufficient funds, take partial bid.
        uint sellValue = toValue(bestPrice, tmsg.amount);
        tmsg.value += sellValue;
        order.amount -= sellValue;
        balances[order.trader] += tmsg.amount;
        orderFIFOs[bestPrice].auxData -= tmsg.amount;
        tmsg.sold += tmsg.amount;
        tmsg.amount = 0;
        Sold (bestPrice, tmsg.amount, tmsg.orderId, msg.sender, order.trader);
        return;
    }

    function makeAsk(TradeMessage tmsg)
        internal
		isMake(tmsg)
	{
        make(tmsg);
        tmsg.sold += tmsg.amount;
        Ask (tmsg.price, tmsg.amount, tmsg.orderId, msg.sender);
        tmsg.amount = 0;
    }

    function makeBid(TradeMessage tmsg)
        internal
		isMake(tmsg)
    {
        make(tmsg);
        tmsg.spent += toValue(tmsg.price, tmsg.amount);
        Bid (tmsg.price, tmsg.amount, tmsg.orderId, msg.sender);
        tmsg.amount = 0;
    }

    function make(TradeMessage tmsg)
        internal
    {
        if (tmsg.amount == 0) return;
        tmsg.orderId = orders.push(Order(tmsg.amount, msg.sender)) - 1;
        if (orderFIFOs[tmsg.price].newNodeKey == NULL) insertFIFO(tmsg.price, tmsg.swap); // Make sure price FIFO index exists
        orderFIFOs[tmsg.price].pushTail(tmsg.orderId); // Insert order ID into price FIFO
        orderFIFOs[tmsg.price].auxData += tmsg.amount; // Update price volume
    }

    function closeOrder(uint _price, uint _orderId)
        internal
        returns (bool)
    {
        orderFIFOs[_price].remove(_orderId);
        orderFIFOs[_price].auxData -= orders[_orderId].amount;
        if (orderFIFOs[_price].size == 0) {
            priceBook.remove(_price);
            delete orderFIFOs[_price].nodes[0];
            delete orderFIFOs[_price];
        }
        delete orders[_orderId];
        return true;
    }
    
    function seekInsert(uint _price, bool _dir)
        internal
        constant
        returns (uint _ret)
    {
        _ret = spread(_dir);
        while (cmp( _price, _ret, _dir))
            _ret = priceBook.nodes[_ret].links[_dir];
        return;
    }
    
    function insertFIFO (uint _price, bool _dir)
        internal
        returns (bool)
    {
        orderFIFOs[_price].init(true);
        uint a = spread(_dir);
        while (cmp( _price, a, _dir))
            a = priceBook.nodes[a].links[_dir];
		priceBook.insertNewNode(a, _price, !_dir); // Insert order ID into price FIFO
        return true;
    }
}




contract EtherPolyPay is ITT
{
	modifier canAccept {
		if (msg.value == 0 || !acceptingPayments) throw;
		_		
	}

	address creator;
	address owner; 

	bool public acceptingPayments;
	uint public paymentsToDate;
	uint public unclaimed;
	
	mapping (address => uint) public lastClaimedAt;
	
//    function ITT(uint _totalSupply, uint8 _decimalPlaces, string _symbol, address _owner)

	function EtherPolyPay(
            uint _supply,
            uint8 _decimalPlaces,
			string _symbol,
			address _owner,
			address _fee_collector,
			uint _feeTokens,
			bool _acceptingPayments) 
            ITT (
                _supply,
                _decimalPlaces,
                _symbol,
                _owner) {
		creator = msg.sender;
		balances[_owner] = totalSupply - _feeTokens;
		balances[_fee_collector] += _feeTokens;
		acceptingPayments = _acceptingPayments;
	}
	
	function() { 
		pay();
	}

	function pay() 
		public
		canAccept
	{
		paymentsToDate += msg.value;
		unclaimed += msg.value;
		PaymentMade(msg.sender, msg.value);
	}
	
   function getEPPMetrics()
        public constant returns (
            uint balance_,
            uint etherBalance_,
            uint claimable_,
            uint lowestAsk_,
            uint highestBid_,
            uint askVol_,
            uint bidVol_,
            uint8 decimalPlaces_,
            uint paymentsToDate_,
			uint totalSupply_,
            uint unclaimed_,
            string symbol_
)
   {
        balance_ = balances[msg.sender];
        etherBalance_ = etherBalances[msg.sender];
	   	claimable_ = claimableEther(msg.sender);
        lowestAsk_ = spread(ASK);
        highestBid_ = spread(BID);
        askVol_ = orderFIFOs[lowestAsk_].auxData;
        bidVol_ = orderFIFOs[highestBid_].auxData;
        decimalPlaces_ = decimalPlaces;
        symbol_ = symbol;
        totalSupply_ = totalSupply;
        unclaimed_ = unclaimed;
        return;
    }
    
	function acceptPayments(bool _accepting) 
		public
		mutexProtected
		isOwner
	{
		acceptingPayments = _accepting;
		AcceptingPayments(acceptingPayments);		
	}

	function claimableEther(address _holder)
		public
		constant
		returns (uint)
	{
		return ((paymentsToDate - lastClaimedAt[_holder]) *
			balances[_holder]) / totalSupply;
	}
		
	function claimEther(address _holder) 
		public
		mutexProtected
	{
		claimEtherInternal(_holder);
	}
	

	function claimEtherInternal(address _holder) 
		internal
	{
		if (uint(_holder) == 0) _holder = msg.sender;
		uint bal = claimableEther(_holder);
		lastClaimedAt[_holder] = paymentsToDate;
		if (bal > 0) {
			etherBalances[_holder] += bal;
			unclaimed -= bal;
			Claimed(_holder, bal);
		}
	}
	
    function withdraw(uint _ether)
		public
        mutexProtected
        hasEther(msg.sender, _ether)
        returns (bool success_)
    {
    	claimEtherInternal(msg.sender);
        etherBalances[msg.sender] -= _ether;
        if(!msg.sender.send(_ether)) throw;
        success_ = true;
    }

	function transfer(address _holder, uint _amount)
		public
		mutexProtected
        isAvailable(_amount)
        returns (bool success_)
	{
		claimEtherInternal(_holder);
		balances[_holder] += _amount;
		balances[msg.sender] -= _amount;
		Transfer(msg.sender, _holder, _amount);
		success_ = true;
	}

    function transferFrom(address _from, address _to, uint256 _value)
        mutexProtected
        hasAllowance(_from, _value)
        returns (bool success)
    {
		claimEtherInternal(_from);
        balances[_from] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        success = true;
    }

    function buy (uint _bidPrice, uint _amount, bool _make)
        public
        mutexProtected
        returns (bool success_)
    {
        claimEtherInternal(msg.sender);
        buyIntl(_bidPrice, _amount, _make);
        success_ = true;
    }

    function sell (uint _askPrice, uint _amount, bool _make)
        public
        mutexProtected
        returns (bool success_)
    {
        claimEtherInternal(msg.sender);
        sellIntl(_askPrice, _amount, _make);
        success_ = true;
    }

	event AcceptingPayments(bool _acceptingPayments);
	event PaymentMade(address sender, uint amount);
	event Claimed(address holder, uint amount);
}


contract EtherPolyPayFactory is Misc
{

	uint constant MAXFEE = 1000000;
	address owner;
	address feeCollector;
	uint feePercent;
	EtherPolyPay[] instances;
	uint defaultSupply;
	
	function PolyPayFactory(uint _feeTokens, uint defaultSupply) {
		owner = msg.sender;
		feeCollector = msg.sender;
		feePercent = _feeTokens;
	}
	
	function Create(uint _supply, uint8 _decimalPlaces, string _symbol, address _owner, bool _acceptingPayments) returns (EtherPolyPay ppInstance) {
		ppInstance = new EtherPolyPay(_supply, _decimalPlaces, _symbol, _owner, feeCollector, feePercent, _acceptingPayments);
		instances.push(ppInstance);
	}
	
	function setFeePercent(uint _percent) isOwner {
		if (_percent > MAXFEE) throw;
		feePercent = _percent;
	}
	
	function setFeeCollector(address _newOwner) isOwner {
		owner = _newOwner;		
	}
	
	function setOwner(address _newCollector) isOwner {
		feeCollector = _newCollector;		
	}
	
}