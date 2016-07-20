
import 'misc.sol';
import 'ITT.sol';



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
	
	mapping (uint => uint) lastClaimedAt;
	
	function EtherPolyPay(
			string _name,
			address _owner,
			address _fee_collector,
			uint _feeTokens,
			uint _supply,
			bool _acceptingPayments) {
		if (_feeTokens > supply) throw;
		name = _name;
		creator = msg.sender;
		owner = _owner;
		supply = _supply;
		balances[_owner] = supply - _feeTokens;
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
		PaymentMade(msg.sender, msg.value);
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
			balances[_holder]) / supply;
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
        isAvailable(_value)
        returns (bool success)
	{
		claimEtherInternal(_holder);
		holders[_holder].tokens += _amount;
		holders[msg.sender].tokens -= _amount;
		Transfered(msg.sender, _holder, _amount);
		success_ = true;
	}

    function transferFrom(address _from, address _to, uint256 _value)
        mutexProtected
        hasAllowance(_from, _value)
        returns (bool success)
    {
		claimEtherInternal(_holder);
        balances[_from] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        success = true;
    }

	event AcceptingPayments(bool _acceptingPayments);
	event PaymentMade(address sender, uint amount);
	event Claimed(address holder, uint amount);
}


contract PolyPayFactory
{
	modifier isOwner {
		if (msg.sender != owner) throw;
		_
	}
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
	
	function Create(string _name, uint supply, bool _acceptingPayments) returns (EtherPolyPay ppInstance) {
		ppInstance = new EtherPolyPay(_name, msg.sender, feeCollector, feePercent, supply, _acceptingPayments);
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