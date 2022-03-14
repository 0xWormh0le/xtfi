const { expect } = require('chai')
const { ethers } = require('hardhat')
const { utils } = require('ethers')


describe('EthPool', function () {
  beforeEach(async function () {
    const EthPool = await ethers.getContractFactory('EthPool')
    this.ethPool = await EthPool.deploy()
    this.users = await ethers.getSigners()
  })

  it('Non team member cannot deposit reward', async function () {
    const [ team, alice ] = this.users

    // deployer is a member of team by default
    expect(await this.ethPool.hasRole(utils.formatBytes32String(0), team.address)).to.equal(true)

    // alice is not a member of team
    expect(await this.ethPool.hasRole(utils.formatBytes32String(0), alice.address)).to.equal(false)

    // reverts when called from non team member
    await expect(this.ethPool.connect(alice).depositRewards({ value: 10 }))
      .to.revertedWith('Not team member')
  })

  it('First test case in spec', async function () {
    const [ team, alice, bob, carl ] = this.users

    // deposit
    await this.ethPool.connect(alice).deposit({ value: 100 })
    await this.ethPool.connect(bob).deposit({ value: 300 })
    await expect(this.ethPool.connect(team).depositRewards({ value: 200 }))
      .to.emit(this.ethPool, 'RewardDeposited')
      .withArgs(team.address, 200)

    // check reward
    expect(await this.ethPool.rewardBalanceOf(alice.address)).to.equal(50)
    expect(await this.ethPool.rewardBalanceOf(bob.address)).to.equal(150)

    // check withdraw amount available
    expect(await this.ethPool.withdrawBalanceOf(alice.address)).to.equal(100 + 50)
    expect(await this.ethPool.withdrawBalanceOf(bob.address)).to.equal(300 + 150)

    // withdraw
    await expect(this.ethPool.connect(alice).withdraw(carl.address))
      .to.emit(this.ethPool, 'Withdrawn')
      .withArgs(alice.address, 100 + 50)

    await expect(this.ethPool.connect(bob).withdraw(carl.address))
      .to.emit(this.ethPool, 'Withdrawn')
      .withArgs(bob.address, 300 + 150)

    // check withdraw amount available again
    expect(await this.ethPool.withdrawBalanceOf(alice.address)).to.equal(0)
    expect(await this.ethPool.withdrawBalanceOf(bob.address)).to.equal(0)
  })

  it('Second test case in spec', async function () {
    const [ team, alice, bob, carl ] = this.users

    // deposit
    await this.ethPool.connect(alice).deposit({ value: 100 })
    await this.ethPool.connect(team).depositRewards({ value: 200 })
    await this.ethPool.connect(bob).deposit({ value: 350 })

    // check reward
    expect(await this.ethPool.rewardBalanceOf(alice.address)).to.equal(200)
    expect(await this.ethPool.rewardBalanceOf(bob.address)).to.equal(0)

    // check withdraw amount available
    expect(await this.ethPool.withdrawBalanceOf(alice.address)).to.equal(100 + 200)
    expect(await this.ethPool.withdrawBalanceOf(bob.address)).to.equal(350)

    // // withdraw
    await expect(this.ethPool.connect(alice).withdraw(carl.address))
      .to.emit(this.ethPool, 'Withdrawn')
      .withArgs(alice.address, 100 + 200)

    await expect(this.ethPool.connect(bob).withdraw(carl.address))
      .to.emit(this.ethPool, 'Withdrawn')
      .withArgs(bob.address, 350)

    // check withdraw amount available again
    expect(await this.ethPool.withdrawBalanceOf(alice.address)).to.equal(0)
    expect(await this.ethPool.withdrawBalanceOf(bob.address)).to.equal(0)
  })
})
