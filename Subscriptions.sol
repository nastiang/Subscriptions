pragma solidity ^0.8.14;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract Payment is Ownable{
  uint public nextPlanId;

  struct Plan {
    address merchant;
    address token;
    string name;
    uint price;
    string description;
    uint frequency;
    bool isActive;
  }
  struct Subscription {
    address subscriber;
    uint start;
    uint nextPayment;
  }

  mapping(uint => Plan) public plans;
  mapping(uint => uint) planAmount;
  mapping(address => mapping(uint => Subscription)) public subscriptions;
  mapping(uint => address) public subscribers;
  mapping(uint => uint) public subscribeToPlan;
  uint countSubscriptions;

  event PlanCreated(
    address merchant,
    uint planId,
    uint date
  );
  event SubscriptionCreated(
    address subscriber,
    uint planId,
    uint date
  );
  event SubscriptionCancelled(
    address subscriber,
    uint planId,
    uint date
  );
  event PaymentSent(
    address from,
    uint amount,
    uint planId,
    uint date
  );

  function createPlan(address token, string memory name, uint price, string memory description, uint frequency) external {
    require(token != address(0), 'address cannot be null address');
    require(price > 0, 'price needs to be > 0');  //you can set a condition taking into account transaction costs
    require(frequency > 0, 'frequency needs to be > 0');
    plans[nextPlanId] = Plan(
      msg.sender, 
      token,
      name,
      price,
      description,
      frequency,
      true
    );
    nextPlanId++;
  }

  function disablePlan(uint planId) external {
      require(plans[planId].merchant == msg.sender, "You are not merchant of this plan");
      plans[planId].isActive = false;
  }

    function enablePlan(uint planId) external {
      require(plans[planId].merchant == msg.sender, "You are not merchant of this plan");
      plans[planId].isActive = true;
  }

  function subscribe(uint planId) external {
    require(plans[planId].isActive == true, "This plan is disabled");
    IERC20 token = IERC20(plans[planId].token);
    Plan storage plan = plans[planId];
    require(plan.merchant != address(0), 'this plan does not exist');

    token.transferFrom(msg.sender, address(this), plan.price);  
    emit PaymentSent(
      msg.sender, 
      plan.price, 
      planId, 
      block.timestamp
    );

    planAmount[planId] = planAmount[planId] + plan.price;
    subscriptions[msg.sender][planId] = Subscription(
      msg.sender, 
      block.timestamp, 
      block.timestamp + plan.frequency
    );
    countSubscriptions++;
    subscribers[countSubscriptions] = msg.sender;
    subscribeToPlan[countSubscriptions] = planId;
    emit SubscriptionCreated(msg.sender, planId, block.timestamp);
  }

  function unSubscribe(uint planId) external {
    Subscription storage subscription = subscriptions[msg.sender][planId];
    require(
      subscription.subscriber != address(0), 
      'this subscription does not exist'
    );
    delete subscriptions[msg.sender][planId]; 
    emit SubscriptionCancelled(msg.sender, planId, block.timestamp);
  }

    function cancel(uint planId, address subscriber) external  onlyOwner{
    Subscription storage subscription = subscriptions[subscriber][planId];
    require(
      subscription.subscriber != address(0), 
      'this subscription does not exist'
    );
    delete subscriptions[subscriber][planId]; 
    emit SubscriptionCancelled(subscriber, planId, block.timestamp);
  }

  function pay(address subscriber, uint planId) external {
    require(plans[planId].isActive == true, "This plan is disabled");
    Subscription storage subscription = subscriptions[subscriber][planId];
    Plan storage plan = plans[planId];
    IERC20 token = IERC20(plan.token);
    require(
      subscription.subscriber != address(0), 
      'this subscription does not exist'
    );
    require(
      block.timestamp > subscription.nextPayment,
      'not due yet'
    );

    token.transferFrom(subscriber, address(this), plan.price);  
    emit PaymentSent(
      subscriber,
      plan.price, 
      planId, 
      block.timestamp
    );
    planAmount[planId] = planAmount[planId] + plan.price;
    subscription.nextPayment = subscription.nextPayment + plan.frequency;
  }

  function withdraw(uint planId) external {
    require(plans[planId].merchant == msg.sender, "You are not merchant");
    require(planAmount[planId] > 0, "Amount must be > 0 ");
    uint amount = planAmount[planId] / 10 * 9;
    IERC20 token = IERC20(plans[planId].token);
    token.transferFrom(address(this), plans[planId].merchant, amount);  


  }
}
