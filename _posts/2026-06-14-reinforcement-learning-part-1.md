---
layout: post
title: "Reinforcement Learning Part-1"
date: 2026-06-14 00:00:00 +0530
categories: machine-learning
tags: [reinforcement-learning]
author: "Seroze"
published: true
---

*Notes from studying Sutton & Barto and David Silver's lectures.*

---

## What is Reinforcement Learning?

Reinforcement Learning (RL) is about learning through interaction. An agent repeatedly:

1. Observes the environment.
2. Takes an action.
3. Receives a reward.
4. Observes the resulting state.

The objective is **not** to maximize immediate rewards but to maximize **cumulative future reward**.

Unlike supervised learning:
- There are no labels.
- There is no teacher providing the correct action.
- The agent must discover good behavior through trial and error.

---

## The RL Framework

An RL system consists of two entities:

**Agent** — the decision maker.  
Examples: chess engine, robot, trading system.

**Environment** — everything outside the agent.  
Examples: chess board, physical world, financial market.

The interaction loop:

```
State
  ↓
Agent chooses Action
  ↓
Environment responds
  ↓
Reward + Next State
```

---

## States and the Markov Property

A state should contain enough information to predict the future. This leads to the **Markov Property**:

$$P(S_{t+1} \mid S_t) = P(S_{t+1} \mid S_1, \ldots, S_t)$$

Intuitively: given the current state, the past no longer matters.

A useful analogy from distributed systems is a **replicated state machine** — once the log has been applied, the current state is sufficient; the entire history is no longer needed to determine future behavior.

---

## Markov Decision Process (MDP)

Most classical RL assumes the environment is a **Markov Decision Process**, defined by:

$$\langle \mathcal{S}, \mathcal{A}, P, R, \gamma \rangle$$

| Symbol | Meaning |
|--------|---------|
| $$\mathcal{S}$$ | States |
| $$\mathcal{A}$$ | Actions |
| $$P$$ | Transition probabilities |
| $$R$$ | Reward function |
| $$\gamma$$ | Discount factor |

---

## Rewards vs Returns

**Reward** measures immediate feedback:

| Outcome | Reward |
|---------|--------|
| Win game | +1 |
| Lose game | -1 |
| Draw | 0 |

RL optimizes **return**, not reward. Return is the discounted sum of future rewards:

$$G_t = R_{t+1} + \gamma R_{t+2} + \gamma^2 R_{t+3} + \cdots$$

---

## Discount Factor

$$\gamma$$ controls how patient the agent is.

- $$\gamma = 0$$ — only cares about immediate reward.
- $$\gamma \approx 1$$ — values long-term outcomes.

This maps naturally to engineering organizations:
- Low $$\gamma$$ → optimize quarterly metrics.
- High $$\gamma$$ → invest in long-term infrastructure and reliability.

---

## Value Functions

A value function answers: **how good is this state?**

$$V(s) = \mathbb{E}\left[\sum_{k=0}^{\infty} \gamma^k R_{t+k+1} \;\middle|\; S_t = s\right]$$

A state can have immediate reward = 0 yet very high value. In chess, a position may have no immediate reward while being one move away from a forced win.

> **Reward is a fact. Value is a prediction.**

---

## Action-Value Functions

Sometimes we care about specific actions rather than states. This gives us $$Q(s, a)$$:

$$Q(s, a) = \mathbb{E}\left[G_t \mid S_t = s, A_t = a\right]$$

Example:

```
Q(s, Attack) = 80
Q(s, Defend) = 30
→ Choose Attack
```

A policy can be derived directly from Q-values:

$$\pi(s) = \arg\max_a \; Q(s, a)$$

---

## Relationship Between V and Q

If we know all Q-values:

$$V(s) = \max_a \; Q(s, a)$$

Q-values contain more information than state values — they tell us how good every action is, not just the best achievable value. The chain is:

$$Q\text{-values} \;\rightarrow\; V\text{-values} \;\rightarrow\; \text{Policy}$$

---

## Bellman's Key Insight

The most elegant idea in RL: the value of a state can be expressed **recursively**.

Return satisfies:

$$G_t = R_{t+1} + \gamma G_{t+1}$$

Which gives the **Bellman equation**:

$$V(s) = \mathbb{E}\left[R_{t+1} + \gamma V(S_{t+1}) \mid S_t = s\right]$$

In words:

$$\underbrace{V(s)}_{\text{Value now}} = \underbrace{R}_{\text{Reward now}} + \underbrace{\gamma \cdot V(s')}_{\text{Discounted future value}}$$

This recursive structure is the foundation of:
- Dynamic Programming
- TD Learning
- SARSA, Q-Learning
- Value Iteration, Policy Iteration

Most classical RL is just different ways of solving or approximating Bellman equations.

---

## Key Takeaway

The biggest shift in thinking: **RL is not about maximizing immediate rewards — it is about reaching valuable future states.**

A move with zero immediate reward can be better than a move with a positive reward if it leads to a significantly better future.

That single idea motivates value functions, Bellman equations, planning, and much of reinforcement learning itself.

---

## Bellman Equations and the Bellman-Ford Connection

The Bellman equation started feeling much less abstract once I noticed its similarity to shortest path algorithms.

Suppose we have a simple chain of states:

```
A -> B -> Goal
```

with $$V(\text{Goal}) = 100$$ and $$\gamma = 0.9$$.

Using the Bellman update:

$$V(s) = R + \gamma V(s')$$

value propagates **backwards** through the graph:

$$V(B) = 0 + 0.9 \times 100 = 90$$

$$V(A) = 0 + 0.9 \times 90 = 81$$

This immediately reminded me of the **Bellman-Ford shortest path algorithm**, where distance information propagates backwards from the destination through repeated edge relaxations.

In Bellman-Ford we repeatedly update:

$$\text{dist}(u) = \min\bigl(\text{dist}(u),\; w(u,v) + \text{dist}(v)\bigr)$$

In value iteration we repeatedly update:

$$V(s) = \max_a \bigl(R + \gamma V(s')\bigr)$$

The mathematics is surprisingly similar:

- Bellman-Ford propagates **distance** information.
- Value Iteration propagates **reward/value** information.
- Both repeatedly apply local updates until reaching a **fixed point**.

The connection is not accidental. The "Bellman" in Bellman-Ford and the Bellman Equation is the same **Richard Bellman** — one of the pioneers of dynamic programming and sequential decision making.

---

## Synchronous vs Asynchronous Updates

One subtle point is the difference between synchronous and asynchronous Bellman updates.

**Synchronous update** — every new value is computed from the *previous* iteration's values:

$$V^{\text{new}}(A) = R(A) + \gamma \, V^{\text{old}}(B)$$

Every state reads from the old value table and writes to a separate new table, so order of updates does not matter. For the chain example, starting from:

$$V^{\text{old}}(A) = 0, \quad V^{\text{old}}(B) = 0, \quad V^{\text{old}}(\text{Goal}) = 100$$

After one synchronous iteration:

$$V^{\text{new}}(B) = 90, \quad V^{\text{new}}(A) = 0$$

A still sees the old value of B — reward information moves only **one hop per iteration**.

**Asynchronous update** — freshly computed values are used immediately. If we update B first and then A in the same pass:

$$V(B) = 90 \quad \Rightarrow \quad V(A) = 0 + 0.9 \times 90 = 81$$

Both states converge in a single pass.

---

This observation made value iteration feel much more like **graph algorithms** than machine learning. At its core, it is repeatedly propagating information through a state graph until the values converge to a fixed point.

The Bellman-Ford analogy reframes RL from "AI magic" into something that feels much closer to **dynamic programming and graph optimization** — a much more familiar mental model for a systems engineer.

---

## Dynamic Programming, Monte Carlo, and Temporal Difference Learning

After understanding Bellman equations and value iteration, the next question is:

> How do we actually compute the optimal values and policies?

### Policy Evaluation

Suppose someone gives us a policy and asks: *how good is this policy?*

For a fixed policy, we repeatedly apply the Bellman expectation equation until values converge. For the chain:

```
A -> B -> Goal

Reward(A->B)   = 10
Reward(B->Goal) = 100
γ = 0.5
```

```
V(B) = 100
V(A) = 10 + 0.5 * 100 = 60
```

The important observation: we are not trying to improve the policy yet — we are simply **measuring how good it is**.

---

### Policy Improvement

Once we know the value of states, we can ask: *is there a better action available?*

```
Q(S, A) = 50
Q(S, B) = 80
Q(S, C) = 40
```

If the current policy chooses A, we improve it by switching to B. This leads to **Policy Iteration**:

```
Policy → Evaluate → Values → Improve → Better Policy → ...
```

Repeating this process converges to the optimal policy. One nice property: policy improvement cannot make the policy worse — we only switch to actions whose value is at least as good.

---

### Why Dynamic Programming Breaks Down

Dynamic Programming assumes we know every state, action, reward, and transition probability. This quickly becomes impractical for environments with billions of states.

This reminded me of graph algorithms. Bellman-Ford works because the graph is already known. But if you say:

> You don't know the graph. Start walking and discover edges as you go.

Bellman-Ford can no longer be applied directly. This is exactly the transition from **Dynamic Programming to Reinforcement Learning**.

---

### Monte Carlo Methods

Monte Carlo methods solve the problem of not knowing the model. Instead of solving Bellman equations directly, we estimate values from experience.

Suppose every time we start from state S we observe returns:

```
80, 90, 70, 100, 60
```

The simplest estimate:

$$V(S) = \text{Average(Returns)} = 80$$

This works because value is defined as *expected* future return. As we observe more episodes, the estimate converges toward the true value.

> Learn from complete outcomes instead of solving the model.

**The limitation:** Monte Carlo requires waiting until an episode finishes. For a game lasting 5000 steps, the agent must wait for the entire episode before updating any estimate — learning becomes very slow.

---

### Temporal Difference Learning

Temporal Difference (TD) Learning combines Bellman equations with Monte Carlo. Instead of waiting for the final outcome, TD updates estimates **immediately after every transition**.

Suppose:

```
A -> B,  Reward = 10
V(A) = 30,  V(B) = 80,  γ = 0.5
```

The Bellman target is:

$$\text{Target} = 10 + 0.5 \times 80 = 50$$

Our current estimate is $$V(A) = 30$$. The disagreement is the **TD Error**:

$$\delta = \text{Target} - \text{Current Estimate} = 50 - 30 = 20$$

We update by moving gradually toward the target:

$$V(A) \leftarrow V(A) + \alpha \delta$$

With $$\alpha = 0.2$$:

$$V(A) = 30 + 0.2 \times 20 = 34$$

---

### Interpreting TD Error

The sign of the TD error is surprisingly intuitive:

| TD Error | Meaning |
|----------|---------|
| $$\delta > 0$$ | Reality was **better** than expected |
| $$\delta < 0$$ | Reality was **worse** than expected |
| $$\delta = 0$$ | Estimate already satisfies the Bellman relationship |

TD error measures **Bellman inconsistency** between adjacent states.

---

### Bootstrapping

One of the most important ideas in RL is **bootstrapping** — updating an estimate using another estimate.

When we compute:

$$\text{Target} = R + \gamma \cdot V(B)$$

we are using our estimate of B to improve our estimate of A. $$V(B)$$ is not ground truth — it is itself a learned estimate.

This initially feels suspicious, but repeated Bellman updates gradually propagate information through the state graph and drive estimates toward a consistent fixed point.

---

### Monte Carlo vs TD Learning

| | Monte Carlo | Temporal Difference |
|-|-------------|---------------------|
| When to update | After full episode | After every step |
| What to learn from | Actual returns | Estimated future values |
| Bootstrapping | No | Yes |

This distinction is one of the central ideas in Reinforcement Learning.

---

### A New Perspective

The Bellman-Ford analogy became even stronger here.

**Value Iteration** feels like:
> Known graph. Relax every edge repeatedly.

**TD Learning** feels like:
> Unknown graph. Walk through it. Relax only the edges you encounter.

This was the moment RL started feeling less like machine learning and more like **stochastic graph optimization**.
