import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, ContractReceipt } from "ethers";
import { ethers } from "hardhat";

import {
  CustomRouterV3,
  CustomRouterV3__factory,
  Token,
  Token__factory,
  UniswapV2Factory,
  UniswapV2Factory__factory,
  UniswapV2LibraryMock,
  UniswapV2LibraryMock__factory,
  UniswapV2PairC,
  UniswapV2PairC__factory,
  WETH9,
  WETH9__factory,
  Zapper,
  Zapper__factory,
} from "../typechain";

describe("Router V3 tests", function () {
  let Zapper: Zapper;
  let Router: CustomRouterV3;

  let ZapperFactory: Zapper__factory;
  let RouterFactory: CustomRouterV3__factory;

  let WETH: WETH9;
  let UniswapV2Factory: UniswapV2Factory;
  let Token1: Token;
  let Token2: Token;
  let Token3: Token;
  let Token4: Token;
  let UniswapV2LibraryContract: UniswapV2LibraryMock;
  let UniswapV2Pair: UniswapV2PairC;
  let UniswapV2Pair2: UniswapV2PairC;
  let UniswapV2Pair3: UniswapV2PairC;

  let WETHFactory: WETH9__factory;
  let UniswapV2FactoryFactory: UniswapV2Factory__factory;
  let TokenFactory: Token__factory;
  let UniswapV2LibraryFactory: UniswapV2LibraryMock__factory;

  let user: SignerWithAddress;
  let bob: SignerWithAddress;

  before(async function () {
    [user, bob] = await ethers.getSigners();
    WETHFactory = (await ethers.getContractFactory("WETH9", user)) as WETH9__factory;
    UniswapV2FactoryFactory = (await ethers.getContractFactory("UniswapV2Factory", user)) as UniswapV2Factory__factory;
    TokenFactory = (await ethers.getContractFactory("Token", user)) as Token__factory;
    UniswapV2LibraryFactory = (await ethers.getContractFactory(
      "UniswapV2LibraryMock",
      user,
    )) as UniswapV2LibraryMock__factory;
    RouterFactory = (await ethers.getContractFactory("CustomRouterV3", user)) as CustomRouterV3__factory;
    ZapperFactory = (await ethers.getContractFactory("Zapper", user)) as Zapper__factory;
  });

  beforeEach(async () => {
    WETH = await WETHFactory.deploy();
    Token1 = await TokenFactory.deploy("Token1", "T1");
    Token2 = await TokenFactory.deploy("Token2", "T2");
    Token3 = await TokenFactory.deploy("Token3", "T3");
    Token4 = await TokenFactory.deploy("Token4", "T4");
    UniswapV2Factory = await UniswapV2FactoryFactory.deploy(user.address);
    UniswapV2LibraryContract = await UniswapV2LibraryFactory.deploy();

    Router = await RouterFactory.deploy(UniswapV2Factory.address, WETH.address);
    Zapper = await ZapperFactory.deploy(WETH.address, Router.address);
  });

  it("Corect deploy", async () => {
    expect(await Zapper.router()).to.be.equal(Router.address);
  });

  it("Zap TokenA in TokenA-TokenB pool", async () => {
    const tx = await UniswapV2Factory.createPair(Token1.address, Token2.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair.approve(Router.address, ethers.utils.parseEther("100"));
    await Token1.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));
    await Token2.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));

    await addFirstLiquidityTest(Token1, Token2, user, Router);

    await expect(Zapper.zapToken(Token1.address, UniswapV2Pair.address, ethers.utils.parseEther("1")))
      .to.emit(Zapper, "Zap")
      .withArgs("469675790556572410");
  });

  it("Zap TokenA in TokenA-TokenB pool invalid pair", async () => {
    const tx = await UniswapV2Factory.createPair(Token2.address, Token3.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair.approve(Router.address, ethers.utils.parseEther("100"));
    await Token1.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));
    await Token2.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));

    await addFirstLiquidityTest(Token1, Token2, user, Router);

    await expect(
      Zapper.zapToken(Token1.address, UniswapV2Pair.address, ethers.utils.parseEther("1")),
    ).to.be.revertedWith("Invalid pair");
  });

  it("Zap TokenA in TokenB-TokenC pool", async () => {
    const tx = await UniswapV2Factory.createPair(Token2.address, Token3.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair.approve(Router.address, ethers.utils.parseEther("100"));
    const tx2 = await UniswapV2Factory.createPair(Token1.address, Token2.address);
    const receipt2: ContractReceipt = await tx.wait();
    const contractInfo2: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair2 = (await ethers.getContractAt("UniswapV2PairC", contractInfo2[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair2.approve(Router.address, ethers.utils.parseEther("100"));
    const tx3 = await UniswapV2Factory.createPair(Token1.address, Token3.address);
    const receipt3: ContractReceipt = await tx.wait();
    const contractInfo3: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair3 = (await ethers.getContractAt("UniswapV2PairC", contractInfo3[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair3.approve(Router.address, ethers.utils.parseEther("100"));
    await Token1.mint(user.address, ethers.utils.parseEther("100"));
    await Token1.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));
    await Token2.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));
    await Token3.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));

    await addFirstLiquidityTest(Token2, Token3, user, Router);
    await addFirstLiquidityTest(Token1, Token2, user, Router);
    await addFirstLiquidityTest(Token1, Token3, user, Router);

    await expect(Zapper.zapTokenForTokens(Token1.address, UniswapV2Pair.address, ethers.utils.parseEther("1")))
      .to.emit(Zapper, "ZapTokenToTokens")
      .withArgs("447375388541372102");
  });

  it("Zap TokenA in TokenB-TokenC invalid pool", async () => {
    const tx = await UniswapV2Factory.createPair(Token1.address, Token3.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    await expect(Zapper.zapTokenForTokens(Token1.address, UniswapV2Pair.address, ethers.utils.parseEther("1")))
      .to.emit(Zapper, "ZapTokenToTokens")
      .to.be.revertedWith("Invalid pair");
  });

  it("Zap ETH in TokenA-WETH pool", async () => {
    const tx = await UniswapV2Factory.createPair(Token1.address, WETH.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair.approve(Router.address, ethers.utils.parseEther("100"));
    await Token1.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));

    await addFirstLiquidityETHTest(Token1, user, Router);

    await expect(Zapper.zapEth(UniswapV2Pair.address, { value: ethers.utils.parseEther("1") }))
      .to.emit(Zapper, "ZapETH")
      .withArgs("493159580084401031");
  });

  it("Zap ETH in TokenA-WETH invalid pool", async () => {
    const tx = await UniswapV2Factory.createPair(Token1.address, Token2.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair.approve(Router.address, ethers.utils.parseEther("100"));
    await Token1.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));

    await expect(Zapper.zapEth(UniswapV2Pair.address, { value: ethers.utils.parseEther("1") })).to.be.revertedWith(
      "Invalid pair",
    );
  });

  it("Zap ETH in TokenB-TokenC pool", async () => {
    const tx = await UniswapV2Factory.createPair(Token2.address, Token3.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair.approve(Router.address, ethers.utils.parseEther("100"));
    const tx2 = await UniswapV2Factory.createPair(WETH.address, Token2.address);
    const receipt2: ContractReceipt = await tx.wait();
    const contractInfo2: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair2 = (await ethers.getContractAt("UniswapV2PairC", contractInfo2[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair2.approve(Router.address, ethers.utils.parseEther("100"));
    const tx3 = await UniswapV2Factory.createPair(WETH.address, Token3.address);
    const receipt3: ContractReceipt = await tx.wait();
    const contractInfo3: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair3 = (await ethers.getContractAt("UniswapV2PairC", contractInfo3[0]["args"][2])) as UniswapV2PairC;

    UniswapV2Pair3.approve(Router.address, ethers.utils.parseEther("100"));
    await Token2.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));
    await Token3.connect(user).approve(Zapper.address, ethers.utils.parseEther("100"));

    await addFirstLiquidityTest(Token2, Token3, user, Router);
    await addFirstLiquidityETHTest(Token2, user, Router);
    await addFirstLiquidityETHTest(Token3, user, Router);

    await expect(Zapper.zapEthToTokens(UniswapV2Pair.address, { value: ethers.utils.parseEther("1") }))
      .to.emit(Zapper, "ZapETHToTokens")
      .withArgs("447375388541372102");
  });

  it("Zap ETH in TokenB-TokenC invalid pool", async () => {
    const tx = await UniswapV2Factory.createPair(WETH.address, Token3.address);
    const receipt: ContractReceipt = await tx.wait();
    const contractInfo: any = receipt.events?.filter(x => x.event == "PairCreated");
    UniswapV2Pair = (await ethers.getContractAt("UniswapV2PairC", contractInfo[0]["args"][2])) as UniswapV2PairC;

    await expect(
      Zapper.zapEthToTokens(UniswapV2Pair.address, { value: ethers.utils.parseEther("1") }),
    ).to.be.revertedWith("Invalid pair");
  });
});

async function addFirstLiquidityTest(
  Token1: Token,
  Token2: Token,
  user: SignerWithAddress,
  Router: CustomRouterV3,
): Promise<BigNumber> {
  let min_liquidity: BigNumber = BigNumber.from("1000");

  await Token1.mint(user.address, ethers.utils.parseEther("100"));
  await Token2.mint(user.address, ethers.utils.parseEther("100"));

  await Token1.connect(user).approve(Router.address, ethers.utils.parseEther("100"));
  await Token2.approve(Router.address, ethers.utils.parseEther("100"));

  let amountADesired: BigNumber = ethers.utils.parseEther("20");
  let amountBDesired: BigNumber = ethers.utils.parseEther("20");
  let amountAMin: BigNumber = ethers.utils.parseEther("1");
  let amountBMin: BigNumber = ethers.utils.parseEther("1");

  await expect(
    Router.addLiquidity(
      Token1.address,
      Token2.address,
      amountADesired,
      amountBDesired,
      amountAMin,
      amountBMin,
      user.address,
      1,
    ),
  )
    .to.emit(Router, "Liq")
    .withArgs(sqrt(amountADesired.mul(amountBDesired)).sub(min_liquidity));

  let _totalSupply = sqrt(amountADesired.mul(amountBDesired));
  return _totalSupply;
}

const ONE = ethers.BigNumber.from(1);

const TWO = ethers.BigNumber.from(2);

function sqrt(value: any) {
  let x = ethers.BigNumber.from(value);
  let z = x.add(ONE).div(TWO);
  let y = x;
  while (z.sub(y).isNegative()) {
    y = z;
    z = x.div(z).add(z).div(TWO);
  }
  return y;
}

async function addFirstLiquidityETHTest(
  Token1: Token,
  user: SignerWithAddress,
  Router: CustomRouterV3,
): Promise<BigNumber> {
  let min_liquidity: BigNumber = BigNumber.from("1000");
  await Token1.mint(user.address, ethers.utils.parseEther("100"));

  await Token1.approve(Router.address, ethers.utils.parseEther("100"));

  let amountTokenDesired: BigNumber = ethers.utils.parseEther("20");
  let amountEth: BigNumber = ethers.utils.parseEther("20");
  let amountTokenMin: BigNumber = ethers.utils.parseEther("1");
  let amountEthMin: BigNumber = ethers.utils.parseEther("1");

  await expect(
    Router.addLiquidityETH(Token1.address, amountTokenDesired, amountTokenMin, amountEthMin, user.address, 1, {
      value: amountEth,
    }),
  )
    .to.emit(Router, "LiqETH")
    .withArgs(sqrt(amountTokenDesired.mul(amountEth)).sub(min_liquidity));

  let _totalSupply = sqrt(amountTokenDesired.mul(amountEth));
  return _totalSupply;
}
