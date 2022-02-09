// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

interface ERC20Interface {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transferFrom(
        address spender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Transfer(
        address indexed spender,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 oldAmount,
        uint256 amount
    );
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

abstract contract OwnerHelper {
    address[] private _owner;
    enum Vote {
        AGREE,
        DISAGREE,
        UNVOTED
    }
    Vote[] private _vote;
    address private _candidate;
    address private _preOwner;
    enum OwnerStatus {
        ELECTED,
        VOTING
    }
    OwnerStatus private _ownerStatus; // 0은 선출된 상태, 1은 새 후보를 투표중인 상태

    event OwnershipTransferred(
        address indexed preOwner,
        address indexed nextOwner
    );

    modifier onlyOwner() {
        require(
            isOwner(msg.sender) == true,
            "OwnerHelper: caller is not owner"
        );
        _;
    }

    constructor() {
        _owner.push(msg.sender);
        _vote.push(Vote.UNVOTED);
        _ownerStatus = OwnerStatus.VOTING;
    }

    function addInitialOwner(address _owner2, address _owner3)
        public
        onlyOwner
    {
        require(_owner.length == 1);
        _owner.push(_owner2);
        _owner.push(_owner3);
        _vote.push(Vote.UNVOTED);
        _vote.push(Vote.UNVOTED);

        _ownerStatus = OwnerStatus.ELECTED;
    }

    function isOwner(address _addr) public view returns (bool) {
        for (uint8 i = 0; i < _owner.length; i++) {
            if (_owner[i] == _addr) {
                return true;
            }
        }
        return false;
    }

    function getOwnerNum(address _addr) public view returns (uint8) {
        require(isOwner(_addr) == true);
        for (uint8 i = 0; i < _owner.length; i++) {
            if (_owner[i] == _addr) {
                return i;
            }
        }
        return 0;
    }

    function voteTransferOwnership(address _newOwner) public onlyOwner {
        require(_ownerStatus == OwnerStatus.ELECTED); // 현재 투표중이 아니어야 한다.
        require(isOwner(_newOwner) != true); // 새 owner가 기존의 owner가 아니어야 한다
        require(_newOwner != address(0x0)); // 새 owner의 address가 유효해야 한다.

        _ownerStatus = OwnerStatus.VOTING;
        _preOwner = msg.sender;
        _candidate = _newOwner;
        _vote[getOwnerNum(_preOwner)] = Vote.AGREE;
    }

    function transferVote(bool _ballot) public onlyOwner {
        _vote[getOwnerNum(msg.sender)] = _ballot ? Vote.AGREE : Vote.DISAGREE;
        if (checkVoteEnd()) {
            _ownerStatus = OwnerStatus.ELECTED;
            countingVote();
        }
    }

    function checkVoteEnd() private returns (bool end) {
        end = true;
        for (uint8 i = 0; i < _vote.length; i++) {
            if (_vote[i] == Vote.UNVOTED) end = false;
        }
    }

    function countingVote() private {
        //만장일치의 경우에만 ownership이 넘어감
        bool agree = true;
        for (uint8 i = 0; i < _vote.length; i++) {
            if (_vote[i] == Vote.DISAGREE) agree = false;
        }

        if (agree) {
            _owner[getOwnerNum(_preOwner)] = _candidate;
            emit OwnershipTransferred(_preOwner, _candidate);
        }

        _ownerStatus = OwnerStatus.ELECTED;
    }
}

contract SimpleToken is ERC20Interface, OwnerHelper {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) public _allowances;

    uint256 public _totalSupply;
    string public _name;
    string public _symbol;
    uint8 public _decimals;
    bool public _tokenLock;
    mapping(address => bool) public _personalTokenLock;

    constructor(string memory getName, string memory getSymbol) {
        _name = getName;
        _symbol = getSymbol;
        _decimals = 18;
        _totalSupply = 100000000e18;
        _balances[msg.sender] = _totalSupply;
        _tokenLock = true;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        virtual
        override
        returns (bool)
    {
        uint256 currentAllownace = _allowances[msg.sender][spender];
        require(
            currentAllownace >= amount,
            "ERC20: Transfer amount exceeds allowance"
        );
        _approve(msg.sender, spender, currentAllownace, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        emit Transfer(msg.sender, sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        _approve(
            sender,
            msg.sender,
            currentAllowance,
            currentAllowance.sub(amount)
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(
            isTokenLock(sender, recipient) == false,
            "TokenLock: invalid token transfer"
        );
        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[sender] = senderBalance.sub(amount);
        _balances[recipient].add(amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 currentAmount,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        require(
            currentAmount == _allowances[owner][spender],
            "ERC20: invalid currentAmount"
        );
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, currentAmount, amount);
    }

    function isTokenLock(address from, address to)
        public
        view
        returns (bool lock)
    {
        lock = false;

        if (_tokenLock == true) {
            lock = true;
        }

        if (
            _personalTokenLock[from] == true || _personalTokenLock[to] == true
        ) {
            lock = true;
        }
    }

    function removeTokenLock() public onlyOwner {
        require(_tokenLock == true);
        _tokenLock = false;
    }

    function removePersonalTokenLock(address _who) public onlyOwner {
        //require(_personalTokenLock[_who] == true);
        _personalTokenLock[_who] = false;
    }
}
